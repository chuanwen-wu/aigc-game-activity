#!/bin/bash 

# build layer for lambda
set -ex

cd $(dirname $0) || {
    echo "error"
    exit 1
}


tardir=python
layerName=discord_bot_layer_x86_64

rm -rf ${tardir}
mkdir -p ${tardir}
pip3 install --target ${tardir} -qU -r requirements.txt

zip -q -r ./${layerName}.zip $tardir

rm -rf $tardir

jq -n --arg layerName "$layerName" \
      '{"layerName":$layerName}'
