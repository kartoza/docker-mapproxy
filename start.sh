#!/bin/bash

# Create a default mapproxy config is one does not exist in /tilestore
if [ ! -f /tilestore/mapproxy.yaml ]
then
  mapproxy-util create -t base-config tilestore
fi
cd /tilestore
mapproxy-util serve-develop mapproxy.yaml
