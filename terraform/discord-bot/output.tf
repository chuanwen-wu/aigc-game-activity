output "AWSContainerSQSQueueExecutionPolicy" {
  value = aws_iam_policy.AWSContainerSQSQueueExecutionPolicy.arn
}

output "discord_interactions_endpoint_url" {
  value = module.api_gw_lambda.discord_interactions_endpoint_url
}

output "project_id" {
  value = local.unique_project
}

