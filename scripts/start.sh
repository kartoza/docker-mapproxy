#!/bin/bash
source /scripts/env-data.sh
if [ "$1" = '/scripts/run_develop_server.sh' ] || [ "$1" = '/scripts/start.sh' ]; then

    USER_ID=${MAPPROXY_USER_ID:-1000}
    GROUP_ID=${MAPPROXY_GROUP_ID:-1000}

    ###
    # Mapproxy user
    ###
    groupadd -r mapproxy -g "${GROUP_ID}" && \
    useradd -m -d /home/mapproxy/ --gid "${USER_ID}" -s /bin/bash -G mapproxy mapproxy

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

    ###
    # Change  ownership to mapproxy user and mapproxy group
    ###

    mkdir -p "${MAPPROXY_DATA_DIR}" /settings "${MULTI_MAPPROXY_DATA_DIR}" /root/.aws ${MAPPROXY_APP_DIR}
    if [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
        rm -rf "${MULTI_MAPPROXY_DATA_DIR}"/* "${MAPPROXY_DATA_DIR}"/*
    fi
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
        if [[ ! -f "${CONFIG_DATA_PATH}"/mapproxy.log ]];then
            touch "${CONFIG_DATA_PATH}"/mapproxy.log
        fi
        if [[ ! -f "${CONFIG_DATA_PATH}"/source-requests.log ]];then
            touch "${CONFIG_DATA_PATH}"/source-requests.log
        fi
    fi
    # Generate S3 configurations
    if [[ ${ENABLE_S3_CACHE} =~ [Tt][Rr][Uu][Ee] ]];then
      configure_s3_cache
    fi
    chown -R mapproxy:mapproxy "${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings /scripts/ root/.aws ${MAPPROXY_APP_DIR}

    # Check if uwsgi configuration exists
    function uwisgi_config (){
       DATA_PATH=$1
       if [[ ! -f /settings/uwsgi.ini ]]; then
          echo -e "\e[32m No custom uwsgi.ini file, setup using default one from  \033[0m \e[1;31m https://github.com/kartoza/docker-mapproxy/blob/master/uwsgi.ini \033[0m"
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


    # Create a default mapproxy config is one does not exist in /mapproxy
    base_config_generator "${CONFIG_DATA_PATH}"
    pushd "${CONFIG_DATA_PATH}" || exit

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
                mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log.ini
            else
                rm "${CONFIG_DATA_PATH}"/log.ini
                mapproxy-util create -t log-ini --force "${CONFIG_DATA_PATH}"/log.ini
            fi
        fi
        #TODO - Fix sed to replace all commands in one go
        # Add custom logic if it doesn't come from a user defined one
        if [[ ! -f /settings/log.ini ]];then
          sed -i 's/%(here)s/${CONFIG_DATA_PATH}/g' "${CONFIG_DATA_PATH}"/log.ini
          envsubst < "${CONFIG_DATA_PATH}"/log.ini > "${CONFIG_DATA_PATH}"/log.ini.bak
          mv "${CONFIG_DATA_PATH}"/log.ini.bak "${CONFIG_DATA_PATH}"/log.ini
        fi
    fi

    # Add logic to reload the app file
    RELOAD_LOCKFILE=/settings/.app.lock
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
fileConfig(r'${CONFIG_DATA_PATH}/log.ini', {'here': os.path.dirname(__file__)})
      " > /tmp/log.py
      cat "${MAPPROXY_APP_DIR}"/app.py >> /tmp/log.py
      mv  /tmp/log.py  "${MAPPROXY_APP_DIR}"/app.py
    fi
    }


    # Entrypoint logic to start the app
    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        uwisgi_config "${CONFIG_DATA_PATH}"
        make_logs
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        uwisgi_config "${CONFIG_DATA_PATH}"
        export MULTI_MAPPROXY_DATA_DIR ALLOW_LISTING
        envsubst < /multi_mapproxy.py > "${MAPPROXY_APP_DIR}"/app.py
        make_logs
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    else
        exec "$@"
    fi
fi



