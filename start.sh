#!/bin/bash
USER_ID=`ls -lahn /mapproxy | tail -1 | awk {'print $3'}`
GROUP_ID=`ls -lahn /mapproxy | tail -1 | awk {'print $4'}`
USER_NAME=`ls -lah /mapproxy | tail -1 | awk '{print $3}'`

groupadd -g $GROUP_ID mapproxy
useradd --shell /bin/bash --uid $USER_ID --gid $GROUP_ID $USER_NAME
su $USER_NAME

# Create a default mapproxy config is one does not exist in /mapproxy
if [ ! -f /mapproxy/mapproxy.yaml ]
then
  /venv/bin/mapproxy-util create -t base-config mapproxy
fi
cd /mapproxy
/venv/bin/mapproxy-util serve-develop mapproxy.yaml
