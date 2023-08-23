#!/bin/bash
set -v
set -e

# The argument to this script is the region name. 
if [ "$#" -ne 1 ] ; then
    echo "usage: $0 [version]"
    exit 1
fi

version=$1
region='ap-northeast-1'
image_name=sd-game-activity

image_fullname=${image_name}:${version}
docker build -t ${image_fullname} -f Dockerfile.inference.k8s . 

docker run -e auto_exit=1 ${image_fullname}
container_id=$(docker ps -a | grep ${image_fullname} | head -n1 | awk '{print $1}')
docker commit ${container_id} ${image_fullname}-init

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
image_url=${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com/${image_name}:${version}-init
docker tag ${image_name}:${version}-init ${image_url}

# If the repository doesn't exist in ECR, create it.
aws ecr describe-repositories --repository-names "${image_name}" --region ${region} || aws ecr create-repository --repository-name "${image_name}" --region ${region}
if [ $? -ne 0 ]; then
    aws ecr create-repository --repository-name "${inference_image}" --region ${region}
fi

aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com
docker push ${image_url}

echo "Outputs:"
echo "sd_svc_image_url = ${image_url}"
