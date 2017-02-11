#!/bin/bash
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
su $USER_NAME -c "mapproxy-util create -t wsgi-app -f mapproxy.yaml /mapproxy/app.py"
#su $USER_NAME -c "uwsgi --ini /uwsgi.conf"
su $USER_NAME -c "mapproxy-util serve-develop -b 0.0.0.0:8080 mapproxy.yaml"
