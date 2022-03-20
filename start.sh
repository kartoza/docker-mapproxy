#!/bin/bash

if [ "$1" = '/run_develop_server.sh' ] || [ "$1" = '/start.sh' ]; then

    USER_ID=${MAPPROXY_USER_ID:-1000}
    GROUP_ID=${MAPPROXY_GROUP_ID:-1000}

    ###
    # Mapproxy user
    ###
    groupadd -r mapproxy -g "${GROUP_ID}" && \
    useradd -m -d /home/mapproxy/ --gid "${USER_ID}" -s /bin/bash -G mapproxy mapproxy


    ###
    # Change  ownership to mapproxy user and mapproxy group
    ###
    if [[ ! -f "${MAPPROXY_DATA_DIR}"/mapproxy.log ]];then
        touch "${MAPPROXY_DATA_DIR}"/mapproxy.log
    fi
    if [[ ! -f "${MAPPROXY_DATA_DIR}"/source-requests.log ]];then
        touch "${MAPPROXY_DATA_DIR}"/source-requests.log
    fi
    mkdir -p "${MAPPROXY_DATA_DIR}" /settings
    chown -R mapproxy:mapproxy "${MAPPROXY_DATA_DIR}" /settings /start.sh /run_develop_server.sh

    # Check if uwsgi configuration exists
    if [[ ! -f /settings/uwsgi.ini ]]; then
      echo "/settings/uwsgi.ini doesn't exists"
      # If it doesn't exists, copy from /mapproxy directory if exists
      if [[ -f ${MAPPROXY_DATA_DIR}/uwsgi.ini ]]; then
        cp -f "${MAPPROXY_DATA_DIR}"/uwsgi.ini /settings/uwsgi.ini
      else
        # default value
        envsubst < /settings/uwsgi.default.ini > /settings/uwsgi.ini
      fi
    fi
    # Create a default mapproxy config is one does not exist in /mapproxy
    if [ ! -f "${MAPPROXY_DATA_DIR}"/mapproxy.yaml ]
    then
      echo " create base configs"
      mapproxy-util create -t base-config mapproxy
    fi
    pushd "${MAPPROXY_DATA_DIR}" || exit
    # Add logic to reload the app file
    mapproxy-util create -t wsgi-app -f "${MAPPROXY_DATA_DIR}"/mapproxy.yaml "${MAPPROXY_DATA_DIR}"/app.py
    if [[ -f /settings/log.ini ]];then
      cp /settings/log.ini "${MAPPROXY_DATA_DIR}"/log.ini
    else
      mapproxy-util create -t log-ini "${MAPPROXY_DATA_DIR}"/log.ini
    fi
    #TODO - Fix sed to replace all commands in one go
    sed -i 's/%(here)s/${MAPPROXY_DATA_DIR}/g' "${MAPPROXY_DATA_DIR}"/log.ini
    envsubst < "${MAPPROXY_DATA_DIR}"/log.ini > "${MAPPROXY_DATA_DIR}"/log.ini.bak
    mv "${MAPPROXY_DATA_DIR}"/log.ini.bak "${MAPPROXY_DATA_DIR}"/log.ini
    RELOAD_LOCKFILE=/settings/.app.lock
    if [[ ! -f ${RELOAD_LOCKFILE} ]];then
      sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' "${MAPPROXY_DATA_DIR}"/app.py
      touch ${RELOAD_LOCKFILE}
    fi
    if [[ "${LOGGING}" =~ [Tt][Rr][Uu][Ee] ]];then
      echo "
from logging.config import fileConfig
import os.path
fileConfig(r'${MAPPROXY_DATA_DIR}/log.ini', {'here': os.path.dirname(__file__)})
      " > /tmp/log.py
      cat "${MAPPROXY_DATA_DIR}"/app.py >> /tmp/log.py
      mv  /tmp/log.py  "${MAPPROXY_DATA_DIR}"/app.py
    fi
    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    elif [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]] && [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
        envsubst < /multi_mapproxy.py > "${MAPPROXY_DATA_DIR}"/app.py
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    else
        exec "$@"
    fi
fi



