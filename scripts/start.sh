#!/bin/bash

figlet -t "Kartoza Docker MapProxy"
source /scripts/env-data.sh
if [ "$1" = '/scripts/run_develop_server.sh' ] || [ "$1" = '/scripts/start.sh' ]; then

    USER_ID=${MAPPROXY_USER_ID:-1000}
    GROUP_ID=${MAPPROXY_GROUP_ID:-1000}
    USER_NAME=${USER:-mapproxy}
    GEO_GROUP_NAME=${GROUP_NAME:-mapproxy}
    

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


    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        export CONFIG_DATA_PATH="${MAPPROXY_DATA_DIR}"
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        export CONFIG_DATA_PATH="${MULTI_MAPPROXY_DATA_DIR}"
    else
        export CONFIG_DATA_PATH="${MAPPROXY_DATA_DIR}"
    fi

    # Create directories
    mkdir -p "${MAPPROXY_DATA_DIR}" /settings "${MULTI_MAPPROXY_DATA_DIR}" /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}"
    # For development purposes
    if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
        rm -rf "${MULTI_MAPPROXY_DATA_DIR:?}/"* "${MAPPROXY_DATA_DIR:?}/"*
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
        proxy_count=$(find . -maxdepth 1 -type f -name 'mapproxy_*.log' 2>/dev/null | wc -l)
        if [[ $proxy_count != 0 ]];then
          for X in mapproxy_*.log; do
            if [ "$X" != "mapproxy_${HOSTNAME}.log" ]; then
                rm "$X"
            fi
          done
        fi 

        # Cleanup log files for requests
        source_count=$(find . -maxdepth 1 -type f -name 'source-requests_*.log' 2>/dev/null | wc -l)
        if [[ $source_count != 0 ]];then
          for X in source-requests_*.log; do
            if [ "$X" != "source-requests_${HOSTNAME}.log" ]; then
                rm "$X"
            fi
          done
        fi

    fi

    # Generate S3 configurations
    if [[ ${ENABLE_S3_CACHE} =~ [Tt][Rr][Uu][Ee] ]];then
      configure_s3_cache
      python3 /scripts/create_default_buckets.py
    fi

    # Create a default mapproxy config, useful for testing and creating app.py
    base_config_generator "${CONFIG_DATA_PATH}"
	  pushd "${CONFIG_DATA_PATH}" || exit

    # Create app.py for loading app
    if [[ ! -f "${MAPPROXY_APP_DIR}"/app.py ]];then
        mapproxy-util create -t wsgi-app -f "${CONFIG_DATA_PATH}"/mapproxy.yaml "${MAPPROXY_APP_DIR}"/app.py
    else
        rm "${MAPPROXY_APP_DIR}"/app.py
        mapproxy-util create -t wsgi-app -f "${CONFIG_DATA_PATH}"/mapproxy.yaml "${MAPPROXY_APP_DIR}"/app.py
    fi

    samples=("full_example.yaml" "full_seed_example.yaml")
    for file in "${samples[@]}"; do
        if [[ -f "${CONFIG_DATA_PATH}/$file" ]]; then
            rm "${CONFIG_DATA_PATH}/$file" 2> /dev/null || true
        fi
    done


    # check if logging file exists
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
        if [[ -f /settings/log.ini ]];then
          cp /settings/log.ini "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
        else
            # Always create a new log.ini
            if [[ ! -f "${CONFIG_DATA_PATH}"/log.ini ]];then
                mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
            else
                rm "${CONFIG_DATA_PATH}"/log.ini
                mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
            fi
            # cleanup ini files
            pushd "${CONFIG_DATA_PATH}" || exit
            ini_count=$(find . -maxdepth 1 -type f -name 'log_*.ini' 2>/dev/null | wc -l)
            if [[ $ini_count != 0 ]];then
              for X in log_*.ini; do
                if [ "$X" != "log_${HOSTNAME}.ini" ]; then
                    rm "$X"
                fi
              done
            fi

        fi
        
        # Add custom logic if it doesn't come from a user defined one
        if [[ ! -f /settings/log.ini ]];then
          sed -i -e 's|%\(here\)s|'"${CONFIG_DATA_PATH}"'|g' -e 's|mapproxy.log|mapproxy_'"${HOSTNAME}"'.log|g' -e 's|source-requests.log|source-requests_'"${HOSTNAME}"'.log|g' "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
          envsubst < "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini > "${CONFIG_DATA_PATH}"/log.ini.bak
          mv "${CONFIG_DATA_PATH}"/log.ini.bak "${CONFIG_DATA_PATH}"/log_"${HOSTNAME}".ini
        fi
    fi

    # Add logic to reload the app file useful in single mode only. Multi mapproxy auto reloads

    RELOAD_LOCKFILE="/settings/.app.lock"
    if [[ ! -f ${RELOAD_LOCKFILE} ]];then
      sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' "${MAPPROXY_APP_DIR}"/app.py
      touch ${RELOAD_LOCKFILE}
    fi
    

    # Entrypoint logic to start the app
    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        uwsgi_config "${CONFIG_DATA_PATH}"
        make_logs
        ###
        # Change  ownership to mapproxy user and mapproxy group / Need to be done last
        ###
        # Chown again - seems to fix issue with resolving all created directories
        dir_ownership=("${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings
          /scripts/ /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}")
        for directory in "${dir_ownership[@]}"; do
          if [[ $(stat -c '%U' "${directory}") != "${USER_NAME}" ]] && [[ $(stat -c '%G' "${directory}") != "${GEO_GROUP_NAME}" ]];then
            chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${directory}"
          fi
        done
        exec gosu "${USER_NAME}" uwsgi --ini /settings/uwsgi.ini
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        uwsgi_config "${CONFIG_DATA_PATH}"
        export MULTI_MAPPROXY_DATA_DIR
        # Allow listing env variable should always be title case.
        if [[ "${ALLOW_LISTING}" =~ [Tt][Rr][Uu][Ee] ]]; then
                  export ALLOW_LISTING=True
              else
                  export ALLOW_LISTING=False
        fi
        envsubst < /multi_mapproxy.py > "${MAPPROXY_APP_DIR}"/app.py
        rm /multi_mapproxy.py
        make_logs
        ###
        # Change  ownership to mapproxy user and mapproxy group
        ###
        dir_ownership=("${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings
          /scripts/ /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}")
        for directory in "${dir_ownership[@]}"; do
          if [[ $(stat -c '%U' "${directory}") != "${USER_NAME}" ]] && [[ $(stat -c '%G' "${directory}") != "${GEO_GROUP_NAME}" ]];then
            chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${directory}"
          fi
        done
        exec gosu "${USER_NAME}" uwsgi --ini /settings/uwsgi.ini
    else
        ###
        # Change  ownership to mapproxy user and mapproxy group
        ###
        dir_ownership=("${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings
          /scripts/ /root/.aws "${MAPPROXY_APP_DIR}" "${MAPPROXY_CACHE_DIR}")
        for directory in "${dir_ownership[@]}"; do
          if [[ $(stat -c '%U' "${directory}") != "${USER_NAME}" ]] && [[ $(stat -c '%G' "${directory}") != "${GEO_GROUP_NAME}" ]];then
            chown -R "${USER_NAME}":"${GEO_GROUP_NAME}" "${directory}"
          fi
        done
        exec "$@"
    fi
fi



