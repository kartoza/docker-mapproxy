#!/bin/bash

if [ "$1" = '/run_develop_server.sh' ] || [ "$1" = '/start.sh' ]; then

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

    mkdir -p "${MAPPROXY_DATA_DIR}" /settings "${MULTI_MAPPROXY_DATA_DIR}"
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
    chown -R mapproxy:mapproxy "${MAPPROXY_DATA_DIR}" "${MULTI_MAPPROXY_DATA_DIR}" /settings /start.sh /run_develop_server.sh

    # Check if uwsgi configuration exists
    function uwisgi_config (){
       DATA_PATH=$1
       if [[ ! -f /settings/uwsgi.ini ]]; then
          echo "/settings/uwsgi.ini doesn't exists"
          # If it doesn't exists, copy from /mapproxy directory if exists
          if [[ -f ${DATA_PATH}/uwsgi.ini ]]; then
            cp -f "${DATA_PATH}"/uwsgi.ini /settings/uwsgi.ini
          else
            # default value
            envsubst < /settings/uwsgi.default.ini > /settings/uwsgi.ini
          fi
        fi
    }


    # Create a default mapproxy config is one does not exist in /mapproxy
    base_config_generator "${CONFIG_DATA_PATH}"
    pushd "${CONFIG_DATA_PATH}" || exit

    mapproxy-util create -t wsgi-app -f "${CONFIG_DATA_PATH}"/mapproxy.yaml "${CONFIG_DATA_PATH}"/app.py
    rm "${CONFIG_DATA_PATH}"/full_example.yaml  "${CONFIG_DATA_PATH}"/full_seed_example.yaml
    # check if logging file exists
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
        if [[ -f /settings/log.ini ]];then
          cp /settings/log.ini "${CONFIG_DATA_PATH}"/log.ini
        else
          mapproxy-util create -t log-ini "${CONFIG_DATA_PATH}"/log.ini
        fi
        #TODO - Fix sed to replace all commands in one go
        sed -i 's/%(here)s/${CONFIG_DATA_PATH}/g' "${CONFIG_DATA_PATH}"/log.ini
        envsubst < "${CONFIG_DATA_PATH}"/log.ini > "${CONFIG_DATA_PATH}"/log.ini.bak
        mv "${CONFIG_DATA_PATH}"/log.ini.bak "${CONFIG_DATA_PATH}"/log.ini
    fi

    # Add logic to reload the app file
    RELOAD_LOCKFILE=/settings/.app.lock
    if [[ ! -f ${RELOAD_LOCKFILE} ]];then
      sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' "${CONFIG_DATA_PATH}"/app.py
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
      cat "${CONFIG_DATA_PATH}"/app.py >> /tmp/log.py
      mv  /tmp/log.py  "${CONFIG_DATA_PATH}"/app.py
    fi
    }

    # Entrypoint logic to start the app
    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        uwisgi_config "${CONFIG_DATA_PATH}"
        make_logs
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        uwisgi_config "${CONFIG_DATA_PATH}"
        envsubst < /multi_mapproxy.py > "${CONFIG_DATA_PATH}"/app.py
        make_logs
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    else
        exec "$@"
    fi
fi



