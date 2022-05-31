#!/bin/bash

source /scripts/env-data.sh

# run the development server
if [[  ${MULTI_MAPPROXY} =~ [Tt][Rr][Uu][Ee] ]];then
    mapproxy-util serve-multiapp-develop -b 0.0.0.0:8080 "${MULTI_MAPPROXY_DATA_DIR}"
else
  mapproxy-util serve-develop -b 0.0.0.0:8080 "${MAPPROXY_DATA_DIR}"/mapproxy.yaml

fi