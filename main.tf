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
resource "aws_cloudwatch_log_group" "lambda_api_s3_log_group" {
  name = "/aws/lambda/ei_bg_lambda_file_upload"
  # Additional configurations if needed
}

resource "aws_lambda_permission" "allow_lambda1_cloudwatch_logs" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_upload_lambda.arn
  principal     = "logs.amazonaws.com"
  source_arn    = aws_cloudwatch_log_group.lambda_api_s3_log_group.arn
}

# Lambda API S3 Function
data "archive_file" "lambda_function_archive" {
  type        = "zip"
  source_dir  = "${path.module}/LambdaAPIS3/src/LambdaAPIS3/bin/release/net6.0"
  output_path = "${path.module}/LambdaAPIS3/src/LambdaAPIS3/bin/release/net6.0/LambdaAPIS3.zip"
}

resource "aws_lambda_function" "file_upload_lambda" {
  function_name = "ei_bg_file_upload_lambda"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "LambdaAPIS3"
  runtime       = "dotnet6"
  filename      = data.archive_file.lambda_function_archive.output_path

  # CloudWatch Logs configuration
  tracing_config {
    mode = "PassThrough"
  }
  
#  environment {
#    variables = {
#      BUCKET_NAME = aws_s3_bucket.lambda_bucket.bucket,
#    }
#  }

  # Set the timeout to 20 seconds
  timeout = 20
}

resource "aws_lambda_function_url" "test_latest" {
  function_name      = aws_lambda_function.file_upload_lambda.function_name
  authorization_type = "NONE"
}

# resource "aws_lambda_function" "image_converter_lambda" {
#   function_name = "ei_bg_image_converter_lambda"
#   role          = aws_iam_role.lambda_execution_role.arn
#   handler       = "LambdaAPIS3"
#   runtime       = "dotnet6"
#   filename      = data.archive_file.lambda_function_archive.output_path

#   # CloudWatch Logs configuration
#   tracing_config {
#     mode = "PassThrough"
#   }

#   #  environment {
#   #    variables = {
#   #      BUCKET_NAME = aws_s3_bucket.lambda_bucket.bucket,
#   #    }
#   #  }

#   # Set the timeout to 20 seconds
#   timeout = 20
# }

# Lambda Image Converter Function
# data "archive_file" "lambda_function_archive" {
#   type        = "zip"
#   source_dir  = "${path.module}/LambdaImageConverterS3/src/LambdaImageConverterS3/bin/release/net6.0/publish"
#   output_path = "${path.module}/LambdaImageConverterS3/src/LambdaImageConverterS3/bin/release/net6.0/LambdaImageConverterS3.zip"
# }

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