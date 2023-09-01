# API Gateway, Discord Lambda handler, and SQS
locals {
  discord_api_to_lambda = "lambda-api-${var.project_id}"
  cloud_watch_group     = "/aws/lambda/${local.discord_api_to_lambda}"
}

# Create the SQS Queue
resource "aws_sqs_queue" "default_queue" {
  name                        = "${var.project_id}.fifo"
  visibility_timeout_seconds  = 120
  max_message_size            = 262144
  receive_wait_time_seconds   = 20
  sqs_managed_sse_enabled     = true
  fifo_queue                  = true
  content_based_deduplication = true
}

### API Gateway ###
resource "aws_apigatewayv2_api" "discord_gw" {
  name          = "discord-diffusion"
  description   = "HTTP Gateway for Discord Requests"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["OPTIONS", "PUT"]
    allow_origins = ["https://discord.com"]
  }
  ## Note: payload_format_version must be version 2.0 for this project
  target    = aws_lambda_function.discord_api_to_lambda.arn
  route_key = "POST /"
  depends_on = [
    aws_lambda_function.discord_api_to_lambda
  ]
}

resource "aws_lambda_permission" "apigw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.discord_api_to_lambda.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.discord_gw.execution_arn}/*/*"
}


### Discord API First Response ###
resource "aws_lambda_function" "discord_api_to_lambda" {
  function_name    = local.discord_api_to_lambda
  description      = "Discord api endpoint"
  filename         = "${path.module}/discord_endpoint_src.zip"
  source_code_hash = data.archive_file.discord_api_to_lambda.output_base64sha256
  # runtime          = "python${var.python_runtime_version}"
  runtime          = "python${data.external.python_runtime_version.result.version}"
  architectures    = ["x86_64"]
  role             = aws_iam_role.discord_api_to_lambda.arn
  handler          = "lambda_function.lambda_handler"
  layers = [
    # var.requests_arn,
    aws_lambda_layer_version.discord_bot_layer.arn
  ]
  environment {
    variables = {
      APPLICATION_ID = var.discord_application_id,
      PUBLIC_KEY     = var.discord_public_key,
      SQS_QUEUE_URL  = aws_sqs_queue.default_queue.url
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.discord_api_to_lambda,
    aws_iam_role_policy_attachment.discord_api_to_lambda_sqs,
    aws_cloudwatch_log_group.discord_api_to_lambda,
    data.archive_file.discord_api_to_lambda,
    data.external.python_runtime_version
  ]
}

data "archive_file" "discord_api_to_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/discord_endpoint_src.zip"
}

resource "aws_cloudwatch_log_group" "discord_api_to_lambda" {
  name              = local.cloud_watch_group
  retention_in_days = 14
}

resource "aws_iam_policy" "discord_api_lambda_logging" {
  name        = "apigw-logging-${var.project_id}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:${var.region}:${var.account_id}:log-group:${local.cloud_watch_group}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_send_sqs_message" {
  name        = "LambdaWriteSQS-${var.project_id}"
  path        = "/"
  description = "IAM policy for writing to sqs queue"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "sqs:SendMessage",
        "Resource" : "${aws_sqs_queue.default_queue.arn}"
      }
    ]
  })
}

resource "aws_iam_role" "discord_api_to_lambda" {
  name = local.discord_api_to_lambda
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.discord_api_lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "discord_api_to_lambda_sqs" {
  role       = aws_iam_role.discord_api_to_lambda.name
  policy_arn = aws_iam_policy.lambda_send_sqs_message.arn
}

resource "aws_lambda_layer_version" "discord_bot_layer" {
  # filename                 = "${path.module}/layer/discord_bot_layer_x86_64.zip"
  filename                 = "${path.module}/layer/${data.external.build_layer.result.layerName}.zip"
  # layer_name               = "${var.project_id}-pynacl"
  layer_name               = "${var.project_id}-discord_bot_layer"
  compatible_runtimes      = ["python${data.external.python_runtime_version.result.version}"]
  compatible_architectures = ["x86_64"]
  depends_on               = [
    data.external.build_layer, 
    data.external.python_runtime_version
  ]
}

data "external" "build_layer" {
  program = ["bash","${path.module}/layer/build.sh"]
  # query = {
  #   p_env = "dev"
  # }
}


data "external" "python_runtime_version" {
  # program = [
  #   "echo", <<-EOT
  #     {"version":"$(python3 --version | awk '{print $2}' | awk -F '.' '{printf(\"%s.%s\", $1, $2)}')"}
  #   EOT
  # ]
  # program = [
  #   "echo", 
  #     "{\"version\":\"$(git rev-parse --short HEAD)\"}"
  # ]
    program = ["bash","${path.module}/layer/get_python_version.sh"]

}
# output "discord_bot_layer_name" {
#   value = data.external.build_layer.result.layerName
# }