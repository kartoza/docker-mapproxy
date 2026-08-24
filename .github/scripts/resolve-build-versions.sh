#!/usr/bin/env bash

set -euo pipefail

: "${PYTHON_MAJOR_VERSION:?PYTHON_MAJOR_VERSION is required}"
: "${PYTHON_MINOR_VERSION:?PYTHON_MINOR_VERSION is required}"

python_series="${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION}"

python_version=$(curl --fail --silent --show-error \
  "https://hub.docker.com/v2/repositories/library/python/tags?page_size=100&name=${python_series}." |
  jq -r '.results[].name' |
  grep -E "^${python_series//./\\.}\\.[0-9]+$" |
  sort -V |
  tail -n 1)

python_image="python:${python_version}"
docker pull --quiet "${python_image}"
repo_digest=$(docker image inspect "${python_image}" --format '{{index .RepoDigests 0}}')
python_image_sha=${repo_digest#*@}

mapproxy_version=$(curl --fail --silent --show-error \
  https://pypi.org/pypi/MapProxy/json | jq -r '.info.version')

echo "Configured Python series: ${python_series}"
echo "Resolved Python:   ${python_version}@${python_image_sha}"
echo "MapProxy: ${mapproxy_version}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "python_version=${python_version}" >> "${GITHUB_OUTPUT}"
  echo "python_image_sha=${python_image_sha}" >> "${GITHUB_OUTPUT}"
  echo "mapproxy_version=${mapproxy_version}" >> "${GITHUB_OUTPUT}"
fi
