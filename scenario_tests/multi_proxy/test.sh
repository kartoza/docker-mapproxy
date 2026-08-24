#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    COMPOSE=(docker compose)
fi

function compose() {
  "${COMPOSE[@]}" "$@"
}

function directory_compose() {
  "${COMPOSE[@]}" -f docker-compose.yml -f docker-compose.directory-layout.yml "$@"
}

function cleanup() {
  local exit_code=$?
  trap - EXIT
  directory_compose down -v >/dev/null 2>&1 || true
  compose down -v >/dev/null 2>&1 || true
  find cache_dir -mindepth 1 ! -name '.gitkeep' -delete
  if [[ -d cache_dir_directory ]]; then
    find cache_dir_directory -mindepth 1 -delete
    rmdir cache_dir_directory
  fi
  if [[ -d directory_layout ]]; then
    find directory_layout -mindepth 1 -delete
    rmdir directory_layout
  fi
  sed -i.bak '/^[[:space:]]*base_dir: "\/cache_dir\//d' mapproxy_configuration/demo.yaml mapproxy_configuration/mapproxy_configuration.yaml
  find mapproxy_configuration -type f ! -name '*.yaml' ! -name '*.yml' -delete
  find mapproxy_configuration -type d -empty -delete
  exit "${exit_code}"
}

trap cleanup EXIT

echo "Test standard flat multi-app layout"
compose up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  compose logs -f &
fi

sleep 15

function seed_config() {
  local layout="$1"
  local config_file="$2"
  local seed_file="$3"
  local label="$4"

  echo "Seed ${label}"
  if [[ ${layout} == directory ]]; then
    seed_output=$(directory_compose exec -T mapproxy mapproxy-seed -f "${config_file}" --seed=world_boundary -c 4 -s "${seed_file}" 2>&1) || {
      printf '%s\n' "${seed_output}" | tee error.txt
      exit 1
    }
  elif ! seed_output=$(compose exec -T mapproxy mapproxy-seed -f "${config_file}" --seed=world_boundary -c 4 -s "${seed_file}" 2>&1); then
    printf '%s\n' "${seed_output}" | tee error.txt
    exit 1
  fi
}

seed_config flat /multi_mapproxy/mapproxy_configuration.yaml /multi_mapproxy/seed.yaml mapproxy_configuration
seed_config flat /multi_mapproxy/demo.yaml /multi_mapproxy/seed.yaml demo
compose exec -T mapproxy test -f /cache_dir/mapproxy_configuration/world.mbtiles
compose exec -T mapproxy test -f /cache_dir/demo/world_demo.mbtiles

compose down -v

echo "Test opt-in directory multi-app layout"
mkdir -p directory_layout/demo directory_layout/mapproxy_configuration cache_dir_directory
cp mapproxy_configuration/demo.yaml directory_layout/demo/demo.yaml
cp mapproxy_configuration/mapproxy_configuration.yaml directory_layout/mapproxy_configuration/mapproxy.yaml
cp mapproxy_configuration/seed.yaml directory_layout/seed.yaml

directory_compose up -d
sleep 15

seed_config directory /multi_mapproxy/mapproxy_configuration/mapproxy.yaml /multi_mapproxy/seed.yaml mapproxy_configuration-directory
seed_config directory /multi_mapproxy/demo/demo.yaml /multi_mapproxy/seed.yaml demo-directory
directory_compose exec -T mapproxy test -f /cache_dir/mapproxy_configuration/world.mbtiles
directory_compose exec -T mapproxy test -f /cache_dir/demo/world_demo.mbtiles
