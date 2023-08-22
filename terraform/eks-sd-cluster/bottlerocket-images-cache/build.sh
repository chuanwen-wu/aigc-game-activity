#!/bin/bash
set -v
set -e

# The argument to this script is the region name. 
if [ "$#" -ne 1  ] ; then
    echo "usage: $0 [version]"
    exit 1
fi

version=$1
inference_fullname=public.ecr.aws/r7r9s7c1/sd-game-activity:${version}
subnet=subnet-0987a2ef1a097e4ba
region=ap-northeast-1
./r_snapshot.sh -r $region -i g5.xlarge -s ${subnet} $region \
    -a /aws/service/bottlerocket/aws-k8s-1.25-nvidia/x86_64/latest/image_id public.ecr.aws/r7r9s7c1/sd-game-activity:${version}
