#!/bin/bash

if [[ ${NGINX_HOST} == 'mapproxy' ]];then
  export URL="http://localhost/mapproxy/service?"
else
  export URL="http://localhost/mapproxy/${NGINX_HOST}/service?"
fi
envsubst < /web/index.html.bck > /web/index.html
