#!/bin/bash
# Check if uwsgi configuration exists
if [[ ! -f /settings/uwsgi.ini ]]; then
  echo "/settings/uwsgi.ini doesn't exists"
  # If it doesn't exists, copy from /mapproxy directory if exists
  if [[ -f /mapproxy/uwsgi.ini ]]; then
    cp -f /mapproxy/uwsgi.ini /settings/uwsgi.ini
  else
    # default value
    envsubst </settings/uwsgi.default.ini >/settings/uwsgi.ini
  fi
fi
# Create a default mapproxy config is one does not exist in /mapproxy
if [ ! -f /mapproxy/mapproxy.yaml ]; then
  mapproxy-util create -t base-config mapproxy
fi
cd /mapproxy

# Add logic to reload the app file
mapproxy-util create -t wsgi-app -f mapproxy.yaml /mapproxy/app.py
RELOAD_LOCKFILE=/settings/.app.lock
if [[ ! -f ${RELOAD_LOCKFILE} ]]; then
  # This was commented because the reloader value is inserted with the new app.py we inject through the dockerfile
  # sed -i 's/\(, reloader=True\)*'\)'/, reloader=True\)/g' app.py
  touch ${RELOAD_LOCKFILE}
fi
#su $USER_NAME -c "uwsgi --ini /uwsgi.conf"
sed -i -e "s/uid = 1000/uid = $(id -u)/g" /settings/uwsgi.ini
if [[ ${PRODUCTION} =~ [Tt][Rr][Uu][Ee] ]]; then
  exec uwsgi --ini /settings/uwsgi.ini
else
  exec "$@"
fi
