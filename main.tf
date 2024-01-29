provider "aws" {
  profile = "itg-lab"
  region  = "us-east-1"
}

resource "random_id" "id" {
	byte_length = 8
}

# S3 Bucket for File Uploads
resource "aws_s3_bucket" "file_upload_bucket" {
  bucket = var.s3_file_upload_bucket_name # Change this to a unique name
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "ei_bg_lambda_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com",
        },
      },
    ],
  })
  # Attach AWSLambdaBasicExecutionRole managed policy lambda to be able to write cloudwatch logs
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# Attach IAM policy to Lambda Execution Role
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "ei_bg_lambda_execution_policy"
  role = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "lambda:InvokeFunctionURL",
        Effect   = "Allow",
        Resource = aws_lambda_function.file_upload_lambda.arn,
      },
    ],
  })
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "ei_bg_s3_access_policy"
  description = "IAM policy for S3 access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.s3_file_upload_bucket_name}/*",
          "arn:aws:s3:::${var.s3_file_upload_bucket_name}",
        ]
      }
    ]
  })
}

# Attach S3 Access Policy to IAM Role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

# Cloud Watch
# resource "aws_cloudwatch_log_group" "lambda_api_s3_log_group" {
#   name = "/aws/lambda/ei_bg_lambda_file_upload"
#   # Additional configurations if needed
# }

# resource "aws_lambda_permission" "allow_lambda1_cloudwatch_logs" {
#   statement_id  = "AllowExecutionFromCloudWatch"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.file_upload_lambda.arn
#   principal     = "logs.amazonaws.com"
#   source_arn    = aws_cloudwatch_log_group.lambda_api_s3_log_group.arn
# }

# Lambda API Function
data "archive_file" "lambda1_function_archive" {
  type        = "zip"
  source_dir  = "${path.module}/LambdaAPIS3/src/LambdaAPIS3/bin/release/net6.0"
  output_path = "${path.module}/LambdaAPIS3/src/LambdaAPIS3/bin/release/net6.0/LambdaAPIS3.zip"
}

resource "aws_lambda_function" "file_upload_lambda" {
  function_name = "ei_bg_file_upload_lambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "LambdaAPIS3"
  runtime       = "dotnet6"
  filename      = data.archive_file.lambda1_function_archive.output_path

  # CloudWatch Logs configuration
  tracing_config {
    mode = "PassThrough"
  }

  # environment {
  #   variables = {
  #     BUCKET_NAME = aws_s3_bucket.lambda_bucket.bucket,
  #   }
  # }

  # Set the timeout to 20 seconds
  timeout = 20
}

# Lambda Image Converter
data "archive_file" "lambda2_function_archive" {
  type        = "zip"
  source_dir  = "${path.module}/LambdaImageConverterS3/src/LambdaImageConverterS3/bin/release/net6.0"
  output_path = "${path.module}/LambdaImageConverterS3/src/LambdaImageConverterS3/bin/release/net6.0/LambdaImageConverterS3.zip"
}

resource "aws_lambda_function" "image_converter_lambda" {
  function_name = "ei_bg_image_converter_lambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "LambdaImageConverterS3::LambdaImageConverterS3.Function::FunctionHandler"
  runtime       = "dotnet6"
  filename      = data.archive_file.lambda2_function_archive.output_path

  # CloudWatch Logs configuration
  tracing_config {
    mode = "PassThrough"
  }

  environment {
    variables = {
      BUCKET_NAME = var.s3_file_upload_bucket_name,
    }
  }

  # Set the timeout to 20 seconds
  timeout = 20
}

# Cloud Watch
# resource "aws_cloudwatch_log_group" "lambda_img_converter_log_group" {
#   name = "/aws/lambda/ei_bg_lambda_image_converter"
#   # Additional configurations if needed
# }

# resource "aws_lambda_permission" "allow_lambda2_cloudwatch_logs" {
#   statement_id  = "AllowExecutionFromCloudWatch"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.image_converter_lambda.arn
#   principal     = "logs.amazonaws.com"
#   source_arn    = aws_cloudwatch_log_group.lambda_img_converter_log_group.arn
# }

# SNS
# data "aws_iam_policy_document" "ei_bg_s3_sns_topic_policy" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["s3.amazonaws.com"]
#     }

#     actions   = ["SNS:Publish"]
#     resources = ["arn:aws:sns:*:*:ei_bg_file_upload_topic"]

#     condition {
#       test     = "ArnLike"
#       variable = "aws:SourceArn"
#       values   = [aws_s3_bucket.file_upload_bucket.arn]
#     }
#   }
# }

resource "aws_sns_topic" "file_upload_topic" {
  name = "ei_bg_file_upload_topic"
  //policy = data.aws_iam_policy_document.ei_bg_s3_sns_topic_policy.json
  policy = <<POLICY
  {
      "Version":"2012-10-17",
      "Statement":[{
          "Effect": "Allow",
          "Principal": {"Service":"s3.amazonaws.com"},
          "Action": "SNS:Publish",
          "Resource":  "arn:aws:sns:*:*:ei_bg_file_upload_topic",
          "Condition":{
              "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.file_upload_bucket.arn}"}
          }
      }]
  }
  POLICY
}

resource "aws_sns_topic_subscription" "file_upload_topic_subscription" {
  topic_arn = aws_sns_topic.file_upload_topic.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

# Set up S3 event trigger lambda and sns
resource "aws_s3_bucket_notification" "s3_lambda_n_sns_trigger" {
  bucket = aws_s3_bucket.file_upload_bucket.id
  topic {
    topic_arn     = aws_sns_topic.file_upload_topic.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "thumbnails/"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.image_converter_lambda.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix       = "images/"
  }
}

resource "aws_lambda_permission" "s3_lambda_img_converter_trigger_permission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_converter_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.file_upload_bucket.id}"
}

# https://advancedweb.hu/how-to-use-the-aws_apigatewayv2_api-to-add-an-http-api-to-a-lambda-function/
# Create API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api_gw" {
  name          = "ei-bg-apigw"
  # name = "api-${random_id.id.hex}"
  protocol_type = "HTTP"
  target        = aws_lambda_function.file_upload_lambda.arn
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "HEAD", "OPTIONS", "POST"]
  }
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.http_api_gw.id
  name        = "dev"
  auto_deploy = true

  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.main_api_gw.arn

  #   format = jsonencode({
  #     requestId               = "$context.requestId"
  #     sourceIp                = "$context.identity.sourceIp"
  #     requestTime             = "$context.requestTime"
  #     protocol                = "$context.protocol"
  #     httpMethod              = "$context.httpMethod"
  #     resourcePath            = "$context.resourcePath"
  #     routeKey                = "$context.routeKey"
  #     status                  = "$context.status"
  #     responseLength          = "$context.responseLength"
  #     integrationErrorMessage = "$context.integrationErrorMessage"
  #     }
  #   )
  # }
}

# resource "aws_cloudwatch_log_group" "main_api_gw" {
#   name = "/aws/api-gw/${aws_apigatewayv2_api.http_api_gw.name}"
#   retention_in_days = 30
# }

# REST API requires more configuration while above config is sufficient for HTTP API 
# resource "aws_apigatewayv2_integration" "api_gw_integration" {
#   api_id           = aws_apigatewayv2_api.http_api_gw.id
#   integration_type = "AWS_PROXY"
#   integration_uri  = aws_lambda_function.file_upload_lambda.invoke_arn
# }

# resource "aws_apigatewayv2_route" "all_routes" {
#   api_id = aws_apigatewayv2_api.http_api_gw.id
#   route_key = "ANY /{proxy+}"
#   # route_key = "GET /"
#   target    = "integrations/${aws_apigatewayv2_integration.api_gw_integration.id}"
# }

# Create Lambda function permission for API Gateway
resource "aws_lambda_permission" "function_resource_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api_gw.execution_arn}/*/*"
}

# Commented out so lambda can be only invoked by api gateway
# resource "aws_lambda_function_url" "test_latest" {
#   function_name      = aws_lambda_function.file_upload_lambda.function_name
#   authorization_type = "NONE"
# }