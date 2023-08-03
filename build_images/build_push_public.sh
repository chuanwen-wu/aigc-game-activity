#!/bin/bash
set -v
set -e

# The argument to this script is the region name. 
if [ "$#" -ne 1 ] ; then
    echo "usage: $0 [region-name]"
    exit 1
fi

region=$1
account=$(aws sts get-caller-identity --query Account --output text)
version=0.21

if [ $? -ne 0 ]
then
    exit 255
fi

inference_image=sd-game-activity
inference_fullname=public.ecr.aws/r7r9s7c1/sd-game-activity:${version}

# If the repository doesn't exist in ECR, create it.
aws ecr describe-repositories --repository-names "${inference_image}" --region ${region} || aws ecr create-repository --repository-name "${inference_image}" --region ${region}

if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${inference_image}" --region ${region}
fi

aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/r7r9s7c1
docker build -t ${inference_image} -f Dockerfile.inference.k8s . 
docker tag ${inference_image} ${inference_fullname}
docker push ${inference_fullname}
