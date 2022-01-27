#!/bin/bash
echo "Running  $1 "
if [ "$1" = '/run_develop_server.sh' ] || [ "$1" = '/start.sh' ]; then

    USER_ID=${MAPPROXY_USER_ID:-1000}
    GROUP_ID=${MAPPROXY_GROUP_ID:-1000}

    ###
    # Mapproxy user
    ###
    groupadd -r mapproxy -g ${GROUP_ID} && \
    useradd -m -d /home/mapproxy/ --gid ${USER_ID} -s /bin/bash -G mapproxy mapproxy


    ###
    # Change CATALINA_HOME ownership to tomcat user and tomcat group
    # Restrict permissions on conf
    ###
    mkdir -p ${MAPPROXY_DATA_DIR} /settings
    chown -R mapproxy:mapproxy ${MAPPROXY_DATA_DIR} /settings /start.sh /run_develop_server.sh
    chown -R mapproxy:mapproxy ${MAPPROXY_DATA_DIR}

    # Check if uwsgi configuration exists
    if [[ ! -f /settings/uwsgi.ini ]]; then
      echo "/settings/uwsgi.ini doesn't exists"
      # If it doesn't exists, copy from /mapproxy directory if exists
      if [[ -f ${MAPPROXY_DATA_DIR}/uwsgi.ini ]]; then
        cp -f ${MAPPROXY_DATA_DIR}/uwsgi.ini /settings/uwsgi.ini
      else
        # default value
        envsubst < /settings/uwsgi.default.ini > /settings/uwsgi.ini
      fi
    fi
    # Create a default mapproxy config is one does not exist in /mapproxy
    if [ ! -f ${MAPPROXY_DATA_DIR}/mapproxy.yaml ]
    then
      echo " create base configs"
      mapproxy-util create -t base-config mapproxy
    fi
    cd ${MAPPROXY_DATA_DIR}
    # Add logic to reload the app file
    mapproxy-util create -t wsgi-app -f ${MAPPROXY_DATA_DIR}/mapproxy.yaml ${MAPPROXY_DATA_DIR}/app.py
    RELOAD_LOCKFILE=/settings/.app.lock
    if [[ ! -f ${RELOAD_LOCKFILE} ]];then
      sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' ${MAPPROXY_DATA_DIR}/app.py
      touch ${RELOAD_LOCKFILE}
    fi
    if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]]; then
        echo " running in production"
        exec gosu mapproxy uwsgi --ini /settings/uwsgi.ini
    else
        echo " Now running default $@ "
        exec "$@"
    fi
fi


