#!/bin/bash

if [[ -f /settings/uwsgi.ini ]]; then
  rm /settings/uwsgi.ini
fi;
cat > /settings/uwsgi.ini <<EOF
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
chmod-socket = 664
uid = 1000
gid = 10001
EOF


# Create a default mapproxy config is one does not exist in /mapproxy
if [ ! -f /mapproxy/mapproxy.yaml ]
then
  mapproxy-util create -t base-config mapproxy
fi
cd /mapproxy
# Add logic to reload the app file

mapproxy-util create -t wsgi-app -f mapproxy.yaml /mapproxy/app.py
RELOAD_LOCKFILE=/settings/.app.lock
if [[ ! -f ${RELOAD_LOCKFILE} ]];then
  sed -i 's/'\)/', reloader=True\)/g' app.py
  touch ${RELOAD_LOCKFILE}
fi
#su $USER_NAME -c "uwsgi --ini /uwsgi.conf"
exec uwsgi --ini /settings/uwsgi.ini

