#Build the sd service image
aws ecr create-repository --repository-name aigc-service-image
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION='ap-northeast-1'
cluster_name='eks-game-gai'
image_name=controller-img2img


image_url=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image_name}:latest
docker build -t ${image_name} .
docker tag ${image_name}:latest ${image_url}

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker push ${image_url}

#给deployment加iam role的权限。
eksctl create iamserviceaccount --cluster=${cluster_name} --region=${AWS_REGION} --name=img2img-sa --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSContainerSQSQueueExecutionPolicy-discord-sd --approve 