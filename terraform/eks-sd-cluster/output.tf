
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${local.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "eks_api_server_url" {
  description = "Your eks API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_id_list" {
  description = "public_subnet_id_list"
  value       = module.vpc.public_subnets
}

output "efs_id" {
  description = "efs_id"
  value       = aws_efs_file_system.efs.id
}