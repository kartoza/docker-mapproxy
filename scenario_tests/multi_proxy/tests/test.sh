#!/usr/bin/env bash

set -e

source /scripts/env-data.sh

# execute tests
pushd /tests


python3 -m unittest -v ${TEST_CLASS}
