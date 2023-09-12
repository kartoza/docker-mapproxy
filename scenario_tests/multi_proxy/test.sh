#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 10

# seed layers

services=("mapproxy")

for service in "${services[@]}"; do

  # Execute tests
  sleep 5
  echo "Execute seed for $service"
  ${VERSION} exec -T "$service" mapproxy-seed -f /multi_mapproxy/mapproxy.yaml --seed=world_boundary -c 4  -s /multi_mapproxy/seed.yaml
  sleep 5
  ${VERSION} exec -T "$service" mapproxy-seed -f /multi_mapproxy/demo.yaml --seed=world_boundary -c 4  -s /multi_mapproxy/seed.yaml

done

services=("mapproxy")

for service in "${services[@]}"; do

  # Execute tests
  sleep 5
  echo "Execute test for $service"
  ${VERSION} exec -T "$service" /bin/bash /tests/test.sh

done

${VERSION} down -v


find mapproxy_configuration -type f ! -name "*.yaml" ! -name "*.yml" -exec rm -r -f {} \;

find mapproxy_configuration -type f ! -name "*.yaml" ! -name "*.yml" -o -type d -empty -delete
