provider "aws" {
  profile = "itg-lab"
  region = "us-east-1"
}

# S3 Bucket for File Uploads
resource "aws_s3_bucket" "file_upload_bucket" {
  bucket = var.s3_file_upload_bucket_name  # Change this to a unique name
}

# to keep terraform state in aws
# S3 Bucket for Lambda
# resource "aws_s3_bucket" "lambda_bucket" {
#   bucket = var.s3_lambda_bucket_name  # Change this to a unique name
# }

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution_role" {
  name =  "ei_bg_lambda_execution_role"
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

# IAM Policy for Lambda Execution
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name   = "ei_bg_lambda_execution_policy"
  role   = aws_iam_role.lambda_execution_role.id

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
        Action   = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",  # Add this line for delete permissions
        ],
        Effect   = "Allow",
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

# Lambda API S3 Function
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
  # tracing_config {
  #   mode = "PassThrough"
  # }
  
#  environment {
#    variables = {
#      BUCKET_NAME = aws_s3_bucket.lambda_bucket.bucket,
#    }
#  }

  # Set the timeout to 20 seconds
  timeout = 20
}

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

# resource "aws_s3_bucket_notification" "s3_sns_trigger" {
#   bucket = aws_s3_bucket.file_upload_bucket.id
#   topic {
#     topic_arn     = aws_sns_topic.file_upload_topic.arn
#     events        = ["s3:ObjectCreated:*"]
#     filter_prefix = "thumbnails/"
#   }
# }

# Lambda Image Converter Function
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
    events = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] //delete thumbnail if image is removed
    filter_prefix = "images/"
  }
}

resource "aws_lambda_permission" "s3_lambda_img_converter_trigger_permission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_converter_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.file_upload_bucket.id}"
}

resource "aws_lambda_function_url" "test_latest" {
  function_name      = aws_lambda_function.file_upload_lambda.function_name
  authorization_type = "NONE"
}