#!/bin/bash

figlet -t "Kartoza Docker MapProxy"
source /scripts/env-data.sh


USER_ID=${MAPPROXY_USER_ID:-1000}
GROUP_ID=${MAPPROXY_GROUP_ID:-1000}
USER_NAME=${USER:-mapproxy}
GEO_GROUP_NAME=${GROUP_NAME:-mapproxy}

function folder_permission() {
  dir_ownership=("${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings
        /scripts/ /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}" "/docker-entrypoint-mapproxy.d")
  for directory in "${dir_ownership[@]}"; do
    if [[ $(stat -c '%U' "${directory}") != "${USER_NAME}" ]] && [[ $(stat -c '%G' "${directory}") != "${GEO_GROUP_NAME}" ]];then
      chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${directory}"
    fi
  done

}

function create_dir() {
  DATA_PATH=$1
  if [[ ! -d ${DATA_PATH} ]]; then
    mkdir -p "${DATA_PATH}"
  fi
}

function entry_point_script {

  if find "/docker-entrypoint-mapproxy.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    for f in /docker-entrypoint-mapproxy.d/*; do
      case "$f" in
            *.sh)     echo "$0: running $f"; . "$f" || true;;
            *)        echo "$0: ignoring $f" ;;
        esac
        echo
    done
  fi
}

function cleanup_files(){
    PARAM=$1
    EXT='log'
    if [ -n "$2" ]; then
      EXT=$2
    fi
    proxy_count=$(find . -maxdepth 1 -type f -name '${PARAM}_*.log' 2>/dev/null | wc -l)
    if [[ $proxy_count != 0 ]];then
      for X in ${PARAM}_*.${EXT}; do
        if [ "$X" != "${PARAM}_${HOSTNAME}.${EXT}" ]; then
            rm -rf "$X"
        fi
      done
    fi
}


###
# Mapproxy user
###
# Add group
if [ ! $(getent group "${GEO_GROUP_NAME}") ]; then
  groupadd -r "${GEO_GROUP_NAME}" -g "${GROUP_ID}"
fi

# Add user to system
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    useradd -l -m -d /home/"${USER_NAME}"/ -u "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G "${GEO_GROUP_NAME}" "${USER_NAME}"
fi


if [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
    export CONFIG_DATA_PATH="${MAPPROXY_DATA_DIR}"
else
    export CONFIG_DATA_PATH="${MULTI_MAPPROXY_DATA_DIR}"
fi

# Create directories
dir_creation=("${MAPPROXY_DATA_DIR}" /settings "${MULTI_MAPPROXY_DATA_DIR}" /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}" "/docker-entrypoint-mapproxy.d")
for directory in "${dir_creation[@]}"; do
  create_dir "${directory}"
done

# For development purposes
if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
    rm -rf "${CONFIG_DATA_PATH:?}/"*
fi
# Setup logging and cleanup older files
if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
    if [[ ! -f "${CONFIG_DATA_PATH}"/mapproxy_${HOSTNAME}.log ]];then
        touch "${CONFIG_DATA_PATH}"/mapproxy_"${HOSTNAME}".log
    fi
    if [[ ! -f "${CONFIG_DATA_PATH}"/source-requests_"${HOSTNAME}".log ]];then
        touch "${CONFIG_DATA_PATH}"/source-requests_"${HOSTNAME}".log
    fi
    # Cleanup log mapproxy log files
    pushd "${CONFIG_DATA_PATH}" || exit
    cleanup_files "mapproxy"
    cleanup_files "source-requests"

fi # end logging

# Generate S3 configurations
if [[ ${ENABLE_S3_CACHE} =~ [Tt][Rr][Uu][Ee] ]];then
  configure_s3_cache
  python3 /scripts/create_default_buckets.py
fi

# Create a default mapproxy config, useful for testing and creating app.py
if [[ -f /settings/mapproxy.yaml ]];then
  envsubst < /settings/mapproxy.yaml > "${CONFIG_DATA_PATH}"/mapproxy.yaml
  if [[ -f /settings/seed.yaml ]];then
    envsubst < /settings/seed.yaml > "${CONFIG_DATA_PATH}"/seed.yaml
  fi
else
  base_config_generator "${CONFIG_DATA_PATH}"
fi

if [[ "${MAPPROXY_CACHE_DIR}" != '/cache_data' ]];then
  if [[ ! -f "${CONFIG_DATA_PATH}"/.replace.lock ]];then
    sed -i "s|/cache_data|${MAPPROXY_CACHE_DIR}|g" "${CONFIG_DATA_PATH}"/mapproxy.yaml
    touch "${CONFIG_DATA_PATH}"/.replace.lock
  fi
fi
pushd "${CONFIG_DATA_PATH}" || exit

# Create app.py for loading app
if [[ -f "${MAPPROXY_APP_DIR}/app.py" ]]; then
    rm "${MAPPROXY_APP_DIR}/app.py"
fi
mapproxy-util create -t wsgi-app -f "${CONFIG_DATA_PATH}"/mapproxy.yaml "${MAPPROXY_APP_DIR}"/app.py

if [[ "${PRESERVE_EXAMPLE_CONFIGS}" =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  samples=("full_example.yaml" "full_seed_example.yaml")
  for file in "${samples[@]}"; do
      if [[ -f "${CONFIG_DATA_PATH}/$file" ]]; then
          rm "${CONFIG_DATA_PATH}/$file" 2> /dev/null || true
      fi
  done
fi


# check if logging file exists
if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
    if [[ -f /settings/log.ini ]];then
      cp /settings/log.ini "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
    else
        # Always create a new log.ini
        if [[ -f "${CONFIG_DATA_PATH}"/log.ini ]];then
            rm "${CONFIG_DATA_PATH}"/log.ini
        fi
        mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini

        # cleanup ini files
        pushd "${CONFIG_DATA_PATH}" || exit
        cleanup_files "log" "ini"
    fi

    # Add custom logic if it doesn't come from a user defined one
    if [[ ! -f /settings/log.ini ]];then
      sed -i -e 's|%\(here\)s|'"${CONFIG_DATA_PATH}"'|g' -e 's|mapproxy.log|mapproxy_'"${HOSTNAME}"'.log|g' -e 's|source-requests.log|source-requests_'"${HOSTNAME}"'.log|g' "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
      envsubst < "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini > "${CONFIG_DATA_PATH}"/log.ini.bak
      mv "${CONFIG_DATA_PATH}"/log.ini.bak "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
    fi
fi # end logging

# Add logic to reload the app file useful in single mode only. Multi mapproxy auto reloads

RELOAD_LOCKFILE="/settings/.app.lock"
if [[ ! -f ${RELOAD_LOCKFILE} ]];then
  sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' "${MAPPROXY_APP_DIR}"/app.py
  touch ${RELOAD_LOCKFILE}
fi


# Entrypoint logic to start the app
if [[ "$1" == mapproxy-* ]]; then
    # Execute the mapproxy command directly
    make_logs
    folder_permission
    entry_point_script
    exec gosu "${USER_NAME}" "$@"
else
  if  [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
      uwsgi_config "${CONFIG_DATA_PATH}"
      make_logs
      folder_permission
      entry_point_script

      exec gosu "${USER_NAME}" uwsgi --ini /settings/uwsgi.ini
  else
      uwsgi_config "${CONFIG_DATA_PATH}"
      export MULTI_MAPPROXY_DATA_DIR
      # Allow listing env variable should always be title case.
      if [[ "${ALLOW_LISTING}" =~ [Tt][Rr][Uu][Ee] ]]; then
                export ALLOW_LISTING=True
            else
                export ALLOW_LISTING=False
      fi
      if [[ -f /multi_mapproxy.py ]];then
        mv /multi_mapproxy.py /multi_mapproxy.py.sample
      fi
      envsubst < /multi_mapproxy.py.sample > "${MAPPROXY_APP_DIR}"/app.py
      make_logs
      ###
      # Change  ownership to mapproxy user and mapproxy group
      ###
      folder_permission
      entry_point_script
      exec gosu "${USER_NAME}" uwsgi --ini /settings/uwsgi.ini

  fi
fi




