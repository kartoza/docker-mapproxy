#!/bin/bash

if [[ -f /uwsgi.ini ]]; then
  rm /uwsgi.ini
fi;
cat > /uwsgi.ini <<EOF
[uwsgi]
chdir = /mapproxy
pyargv = /mapproxy.yaml
wsgi-file = app.py
pidfile=/tmp/mapproxy.pid
http = 0.0.0.0:8080
processes = $PROCESSES
cheaper = 2
enable-threads = true
threads = $THREADS
master = true
wsgi-disable-file-wrapper = true
req-logger = file:/var/log/uwsgi-requests.log
logger = file:/var/log/uwsgi-errors.log
memory-report = true
harakiri = 60
chmod-socket = 777
EOF

USER_ID=`ls -lahn / | grep mapproxy | awk '{print $3}'`
GROUP_ID=`ls -lahn / | grep mapproxy | awk '{print $4}'`
USER_NAME=`ls -lah / | grep mapproxy | awk '{print $3}'`

groupadd -g $GROUP_ID mapproxy
useradd --shell /bin/bash --uid $USER_ID --gid $GROUP_ID $USER_NAME

# Create a default mapproxy config is one does not exist in /mapproxy
if [ ! -f /mapproxy/mapproxy.yaml ]
then
  su $USER_NAME -c "mapproxy-util create -t base-config mapproxy"
fi
cd /mapproxy
# Add logic to reload the app file

su $USER_NAME -c "mapproxy-util create -t wsgi-app -f mapproxy.yaml /mapproxy/app.py"
RELOAD_LOCKFILE=/mapproxy/.app.lock
if [[ ! -f ${RELOAD_LOCKFILE} ]];then
  sed -i 's/'\)/', reloader=True\)/g' app.py
fi
#su $USER_NAME -c "uwsgi --ini /uwsgi.conf"
exec uwsgi --ini /uwsgi.ini

