#!/bin/bash

if [[ ${NGINX_HOST} == 'mapproxy' ]];then
  if [[ ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]]; then
     export URL="http://localhost/mapproxy/${NGINX_HOST}/service?"
  else
     export URL="http://localhost/mapproxy/service?"
  fi
else
  export URL="http://localhost/mapproxy/${NGINX_HOST}/service?"
fi
envsubst < /web/index.html.bck > /web/index.html
