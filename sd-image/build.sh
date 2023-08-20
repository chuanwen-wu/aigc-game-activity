#!/bin/bash
set -v
set -e

# The argument to this script is the region name. 
if [ "$#" -ne 1 ] ; then
    echo "usage: $0 [version]"
    exit 1
fi

version=$1
inference_image=sd-game-activity
inference_fullname=public.ecr.aws/r7r9s7c1/sd-game-activity:${version}

docker build -t ${inference_image} -f Dockerfile.inference.k8s . 
# docker tag ${inference_image} ${inference_fullname}
# docker push ${inference_fullname}