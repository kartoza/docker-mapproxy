#!/bin/bash
docker kill mapproxy
docker rm mapproxy
mkdir mapproxy
chmod a+wX mapproxy
docker run --name="mapproxy" -v `pwd`/mapproxy:/mapproxy -p 1234:8080 -d -t kartoza/mapproxy
docker logs mapproxy
