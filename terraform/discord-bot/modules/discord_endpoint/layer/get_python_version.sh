#!/bin/bash 

# build layer for lambda
set -ex

version=$(python3 --version | awk '{print $2}' | awk -F '.' '{printf("%s.%s", $1, $2)}')

# echo '{"layerName":"${version}"}'

jq -n --arg version "$version" \
      '{"version":$version}'
