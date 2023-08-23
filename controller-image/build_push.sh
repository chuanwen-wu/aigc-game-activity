#Build the sd controller image
AWS_REGION='ap-northeast-1'
cluster_name='eks-game-gai'
AWSContainerSQSQueueExecutionPolicy="arn:aws:iam::733851053666:policy/AWSContainerSQSQueueExecutionPolicy-discord-sd-gai"

image_name=controller-sd
sa_name=sqsexec-sa

version=0.1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr create-repository --repository-name ${image_name}
image_url=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${image_name}:${version}
docker build -t ${image_name} .
docker tag ${image_name}:latest ${image_url}

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker push ${image_url}
#给deployment加iam role的权限。
eksctl create iamserviceaccount --cluster=${cluster_name} --region=${AWS_REGION} --name=${sa_name} --attach-policy-arn=arn:aws:iam::733851053666:policy/AWSContainerSQSQueueExecutionPolicy-discord-sd-gai --approve 

echo "Outputs:"
echo "controller_sd_image_url = ${image_url}"
echo "service_account = ${sa_name}"
