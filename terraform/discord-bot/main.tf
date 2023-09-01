locals {
  unique_project = "${var.project_id}-${var.unique_id}"
}


# API Gateway, Discord Lambda handler, and SQS
module "api_gw_lambda" {
  source                 = "./modules/discord_endpoint"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = var.region
  discord_application_id = var.discord_application_id
  discord_public_key     = var.discord_public_key
  # pynacl_arn             = aws_lambda_layer_version.pynacl.arn
  # requests_arn           = aws_lambda_layer_version.requests.arn
}

# A Lambda function that creates the Discord UI
module "discord_ui" {
  source                 = "./modules/discord_ui"
  account_id             = data.aws_caller_identity.current.account_id
  project_id             = local.unique_project
  region                 = var.region
  discord_application_id = var.discord_application_id
  # requests_arn           = aws_lambda_layer_version.requests.arn
  discord_bot_secret     = var.discord_bot_secret
}


# Lambda layers to be used for all Lambda functions
# resource "aws_lambda_layer_version" "requests" {
#   filename                 = "files/requests_layer_arm64.zip"
#   layer_name               = "${local.unique_project}-requests"
#   compatible_runtimes      = ["python3.8"]
#   compatible_architectures = ["arm64"]
# }

# resource "aws_lambda_layer_version" "pynacl" {
#   filename                 = "files/pynacl_layer_arm64.zip"
#   layer_name               = "${local.unique_project}-pynacl"
#   compatible_runtimes      = ["python3.8"]
#   compatible_architectures = ["arm64"]
# }


resource "aws_iam_policy" "AWSContainerSQSQueueExecutionPolicy" {
  name        = "AWSContainerSQSQueueExecutionPolicy-${var.project_id}"
  path        = "/"
  description = "IAM policy for containers to query SQS queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",

        ],
        "Resource" : "arn:aws:sqs:${var.region}:${var.account_id}:${var.project_id}-${var.unique_id}.fifo"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}
