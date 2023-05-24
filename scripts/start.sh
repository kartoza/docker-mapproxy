#!/bin/bash

figlet -t "Kartoza Docker MapProxy"
source /scripts/env-data.sh
if [ "$1" = '/scripts/run_develop_server.sh' ] || [ "$1" = '/scripts/start.sh' ]; then

    USER_ID=${MAPPROXY_USER_ID:-1000}
    GROUP_ID=${MAPPROXY_GROUP_ID:-1000}
    

    ###
    # Mapproxy user
    ###
    groupadd -r mapproxy -g "${GROUP_ID}" && \
    useradd -m -d /home/mapproxy/ --uid "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G mapproxy mapproxy

    # Function to creat base configs
    function base_config_generator() {
      DATA_PATH=$1
      if [[  ! -f "${DATA_PATH}"/mapproxy.yaml ]];then
            echo " create base configs"
            mapproxy-util create -t base-config "${DATA_PATH}"
      fi
    }

    # Function to setup S3 configs
        function configure_s3_cache() {
      cat > ${AWS_CONFIG_FILE} <<EOF
[profile ${S3_DEFAULT_PROFILE}]
region=${S3_DEFAULT_REGION}
output=${S3_DEFAULT_OUTPUT}
EOF

  cat > ${AWS_SHARED_CREDENTIALS_FILE} <<EOF
[profile ${S3_DEFAULT_PROFILE}]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF
    }

    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        export CONFIG_DATA_PATH="${MAPPROXY_DATA_DIR}"
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        export CONFIG_DATA_PATH="${MULTI_MAPPROXY_DATA_DIR}"
    else
        export CONFIG_DATA_PATH="${MAPPROXY_DATA_DIR}"
    fi

    # Create directories
    mkdir -p "${MAPPROXY_DATA_DIR}" /settings "${MULTI_MAPPROXY_DATA_DIR}" /root/.aws ${MAPPROXY_APP_DIR} 
    # For development purposes
    if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
        rm -rf "${MULTI_MAPPROXY_DATA_DIR}"/* "${MAPPROXY_DATA_DIR}"/*
    fi
    # Setup logging and cleanup older files
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
        if [[ ! -f "${CONFIG_DATA_PATH}"/mapproxy_${HOSTNAME}.log ]];then
            touch "${CONFIG_DATA_PATH}"/mapproxy_${HOSTNAME}.log
        fi
        if [[ ! -f "${CONFIG_DATA_PATH}"/source-requests_${HOSTNAME}.log ]];then
            touch "${CONFIG_DATA_PATH}"/source-requests_${HOSTNAME}.log
        fi
        # Cleanup log mapproxy log files
        pushd "${CONFIG_DATA_PATH}" || exit
        proxy_count=`ls -1 mapproxy_*.log 2>/dev/null | wc -l`
        if [[ $proxy_count != 0 ]];then
          for X in mapproxy_*.log; do
            if [ "$X" != "mapproxy_${HOSTNAME}.log" ]; then
                rm "$X"
            fi
          done
        fi 

        # Cleanup log files for requests
        source_count=`ls -1 source-requests_*.log 2>/dev/null | wc -l`
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


    # Check if uwsgi configuration exists
    function uwisgi_config (){
       DATA_PATH=$1
       if [[ ! -f /settings/uwsgi.ini ]]; then
          echo -e "\e[32m No custom uwsgi.ini file, setup using default one from  \033[0m \e[1;31m https://github.com/kartoza/docker-mapproxy/blob/master/build_data/uwsgi.ini \033[0m"
          # If it doesn't exists, copy from /mapproxy directory if exists
          if [[ -f ${DATA_PATH}/uwsgi.ini ]]; then
            cp -f "${DATA_PATH}"/uwsgi.ini /settings/uwsgi.ini
          else
            # default value
            export CONFIG_DATA_PATH PROCESSES CHEAPER THREADS MAPPROXY_USER_ID MAPPROXY_GROUP_ID MAPPROXY_APP_DIR
            envsubst < /settings/uwsgi.default.ini > /settings/uwsgi.ini
          fi
        fi
    }


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

    if [[ -f "${CONFIG_DATA_PATH}"/full_example.yaml ]];then
        rm "${CONFIG_DATA_PATH}"/full_example.yaml 2> /dev/null || true
    fi
    if [[ -f "${CONFIG_DATA_PATH}"/full_seed_example.yaml ]];then
        rm "${CONFIG_DATA_PATH}"/full_seed_example.yaml 2> /dev/null || true
    fi


    # check if logging file exists
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
        if [[ -f /settings/log.ini ]];then
          cp /settings/log.ini "${CONFIG_DATA_PATH}"/log.ini
        else
            # Always create a new log.ini
            if [[ ! -f "${CONFIG_DATA_PATH}"/log.ini ]];then
                mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini
            else
                rm "${CONFIG_DATA_PATH}"/log.ini
                mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini
            fi
            # cleanup ini files
            pushd "${CONFIG_DATA_PATH}" || exit
            ini_count=`ls -1 log_*.ini 2>/dev/null | wc -l`
            if [[ $ini_count != 0 ]];then
              for X in log_*.ini; do
                if [ "$X" != "log_${HOSTNAME}.ini" ]; then
                    rm "$X"
                fi
              done
            fi

        fi
        #TODO - Fix sed to replace all commands in one go
        # Add custom logic if it doesn't come from a user defined one
        if [[ ! -f /settings/log.ini ]];then
          sed -i 's/%(here)s/${CONFIG_DATA_PATH}/g' "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini
          sed -i 's/mapproxy.log/mapproxy_${HOSTNAME}.log/g' "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini
          sed -i 's/source-requests.log/source-requests_${HOSTNAME}.log/g' "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini
          envsubst < "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini > "${CONFIG_DATA_PATH}"/log.ini.bak
          mv "${CONFIG_DATA_PATH}"/log.ini.bak "${CONFIG_DATA_PATH}"/log_${HOSTNAME}.ini
        fi
    fi

    # Add logic to reload the app file usful in single mode only. Multi mapproxy auto reloads

    RELOAD_LOCKFILE="/settings/.app.lock"
    if [[ ! -f ${RELOAD_LOCKFILE} ]];then
      sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' "${MAPPROXY_APP_DIR}"/app.py
      touch ${RELOAD_LOCKFILE}
    fi
    # Enable logging module
    function make_logs (){
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
      echo "
from logging.config import fileConfig
import os.path
fileConfig(r'${CONFIG_DATA_PATH}/log_${HOSTNAME}.ini', {'here': os.path.dirname(__file__)})
      " > /tmp/log.py
      cat "${MAPPROXY_APP_DIR}"/app.py >> /tmp/log.py
      mv  /tmp/log.py  "${MAPPROXY_APP_DIR}"/app.py
    fi
    }


    # Entrypoint logic to start the app
    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        uwisgi_config "${CONFIG_DATA_PATH}"
        make_logs
        ###
        # Change  ownership to mapproxy user and mapproxy group / Need to be done last
        ###
        chown -R mapproxy:mapproxy "${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings \
         /scripts/ /root/.aws ${MAPPROXY_APP_DIR} 
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        uwisgi_config "${CONFIG_DATA_PATH}"
        export MULTI_MAPPROXY_DATA_DIR
        # Allow listing env variable should always be title case.
        if [[ "${ALLOW_LISTING}" =~ [Tt][Rr][Uu][Ee] ]]; then
                  export ALLOW_LISTING=True
              else
                  export ALLOW_LISTING=False
        fi
        envsubst < /multi_mapproxy.py > "${MAPPROXY_APP_DIR}"/app.py
        make_logs
        ###
        # Change  ownership to mapproxy user and mapproxy group
        ###
        chown -R mapproxy:mapproxy "${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings \
         /scripts/ /root/.aws ${MAPPROXY_APP_DIR} 
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    else
        ###
        # Change  ownership to mapproxy user and mapproxy group
        ###
        chown -R mapproxy:mapproxy "${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings \
        /scripts/ /root/.aws ${MAPPROXY_APP_DIR} 
        exec "$@"
    fi
fi



