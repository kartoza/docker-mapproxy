#!/bin/bash

figlet -t "Kartoza Docker MapProxy"
source /scripts/env-data.sh


USER_ID=${MAPPROXY_USER_ID:-1000}
GROUP_ID=${MAPPROXY_GROUP_ID:-1000}
USER_NAME=${USER:-mapproxy}
GEO_GROUP_NAME=${GROUP_NAME:-mapproxy}

function multi_mapproxy_config_file() {
  local instance_dir="$1"
  local folder_name
  local config_file

  folder_name=$(basename "${instance_dir}")
  if [[ -f "${instance_dir}/mapproxy.yaml" ]]; then
    printf '%s\n' "${instance_dir}/mapproxy.yaml"
    return 0
  fi
  if [[ -f "${instance_dir}/${folder_name}.yaml" ]]; then
    printf '%s\n' "${instance_dir}/${folder_name}.yaml"
    return 0
  fi

  config_file=$(find "${instance_dir}" -maxdepth 1 -type f -name '*.yaml' ! -name 'seed.yaml' -print -quit)
  [[ -n "${config_file}" ]] || return 1
  printf '%s\n' "${config_file}"
}

function configure_multi_mapproxy_caches() {
  local instance_path
  local -a instance_paths
  local config_file
  local folder_name
  local sanitized_folder_name
  local multi_mapproxy_cache_dir
  local cache_config_result

  if [[ ${MULTI_MAPPROXY_DIRECTORY_LAYOUT} =~ [Tt][Rr][Uu][Ee] ]]; then
    instance_paths=("${MULTI_MAPPROXY_DATA_DIR}"/*/)
  else
    instance_paths=("${MULTI_MAPPROXY_DATA_DIR}"/*.yaml "${MULTI_MAPPROXY_DATA_DIR}"/*.yml)
  fi

  for instance_path in "${instance_paths[@]}"; do
    if [[ ${MULTI_MAPPROXY_DIRECTORY_LAYOUT} =~ [Tt][Rr][Uu][Ee] ]]; then
      [[ -d "${instance_path}" ]] || continue
      config_file=$(multi_mapproxy_config_file "${instance_path%/}") || continue
      folder_name=$(basename "${instance_path%/}")
    else
      [[ -f "${instance_path}" ]] || continue
      [[ $(basename "${instance_path}") != "seed.yaml" ]] || continue
      [[ $(basename "${instance_path}") != "seed.yml" ]] || continue
      config_file="${instance_path}"
      folder_name=$(basename "${instance_path}")
      folder_name=${folder_name%.*}
    fi
    sanitized_folder_name=$(
      printf '%s' "${folder_name}" |
        tr '[:upper:]' '[:lower:]' |
        sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
    )
    [[ -n "${sanitized_folder_name}" ]] || continue

    MULTI_MAPPROXY_CACHE_DIR="${MULTI_MAPPROXY_BASE_CACHE_DIR%/}/${sanitized_folder_name}"
    if [[ ${OVERWRITE_GLOBAL_CACHE} =~ [Tt][Rr][Uu][Ee] ]]; then
      cache_config_result=$(python3 /scripts/set_cache_base_dir.py --overwrite "${config_file}" "${MULTI_MAPPROXY_CACHE_DIR}")
    else
      cache_config_result=$(python3 /scripts/set_cache_base_dir.py "${config_file}" "${MULTI_MAPPROXY_CACHE_DIR}")
    fi
    if [[ ${cache_config_result} == set* ]]; then
      mkdir -p "${MULTI_MAPPROXY_CACHE_DIR}"
    fi
    echo "${folder_name}: ${cache_config_result}"
  done
}

function folder_permission() {
  dir_ownership=("${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings
        /scripts/ /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}"
        "${MULTI_MAPPROXY_BASE_CACHE_DIR}" "/docker-entrypoint-mapproxy.d")
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
            *.py)     echo "$0: running Python script $f"; python3 "$f" || true;;
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
            echo "Removing $X"
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
dir_creation=("${MAPPROXY_DATA_DIR}" /settings "${MULTI_MAPPROXY_DATA_DIR}" /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}" "${MULTI_MAPPROXY_BASE_CACHE_DIR}" "/docker-entrypoint-mapproxy.d")
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

# Create a default mapproxy config, useful for testing and creating app.py.
if [[ ! ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]] && \
   { find "${CONFIG_DATA_PATH}" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) ! -name 'seed.yaml' ! -name 'seed.yml' -print -quit | grep -q . || \
     { [[ ${MULTI_MAPPROXY_DIRECTORY_LAYOUT} =~ [Tt][Rr][Uu][Ee] ]] && find "${CONFIG_DATA_PATH}" -mindepth 2 -maxdepth 2 -type f \( -name '*.yaml' -o -name '*.yml' \) ! -name 'seed.yaml' ! -name 'seed.yml' -print -quit | grep -q .; }; }; then
  configure_multi_mapproxy_caches
elif [[ -f /settings/mapproxy.yaml ]];then
  envsubst < /settings/mapproxy.yaml > "${CONFIG_DATA_PATH}"/mapproxy.yaml
  if [[ -f /settings/seed.yaml ]];then
    envsubst < /settings/seed.yaml > "${CONFIG_DATA_PATH}"/seed.yaml
  fi
else
  base_config_generator "${CONFIG_DATA_PATH}"
fi

LOCK_FILE="${CONFIG_DATA_PATH}/default_path.txt"
LAST_CACHE_DIR=""
if [[ -f "$LOCK_FILE" ]]; then
  LAST_CACHE_DIR=$(cat "$LOCK_FILE")
fi

function configure_cache_dir() {
  local config_file="$1"
  local escaped_cache_dir
  local escaped_last_cache_dir

  [[ -f "${config_file}" ]] || return 0

  escaped_cache_dir=$(printf '%s' "${MAPPROXY_CACHE_DIR}" | sed 's/[&|@]/\\&/g')

  # MapProxy's generated configuration uses /cache_data for file caches,
  # mbtiles and locks. Multi-app configurations may instead use cache_data as
  # a base_dir relative to /multi_mapproxy.
  sed -i -E \
    "s@(^|[[:space:]'\"])/cache_data@\1${escaped_cache_dir}@g" \
    "${config_file}"
  sed -i -E \
    "s|^([[:space:]]*base_dir:[[:space:]]*)/?cache_data([[:space:]]*(#.*)?)$|\1${escaped_cache_dir}\2|" \
    "${config_file}"

  # Allow changing MAPPROXY_CACHE_DIR after the container has already run.
  if [[ -n "${LAST_CACHE_DIR}" ]] && [[ "${LAST_CACHE_DIR}" != "${MAPPROXY_CACHE_DIR}" ]]; then
    escaped_last_cache_dir=$(printf '%s' "${LAST_CACHE_DIR}" | sed 's/[][\\.^$*+?{}()&|@/]/\\&/g')
    sed -i -E "s@${escaped_last_cache_dir}@${escaped_cache_dir}@g" "${config_file}"
  fi
}

if [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
  configure_cache_dir "${CONFIG_DATA_PATH}/mapproxy.yaml"
fi

if [[ "${MAPPROXY_CACHE_DIR}" != "${LAST_CACHE_DIR}" ]]; then
  echo "${MAPPROXY_CACHE_DIR}" > "$LOCK_FILE"
fi
pushd "${CONFIG_DATA_PATH}" || exit

# Create app.py for loading app
if [[ -f "${MAPPROXY_APP_DIR}/app.py" ]]; then
    rm "${MAPPROXY_APP_DIR}/app.py"
fi
if [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
  mapproxy-util create -t wsgi-app -f "${CONFIG_DATA_PATH}"/mapproxy.yaml "${MAPPROXY_APP_DIR}"/app.py
fi

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
      export MULTI_MAPPROXY_DATA_DIR MULTI_MAPPROXY_DIRECTORY_LAYOUT
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
