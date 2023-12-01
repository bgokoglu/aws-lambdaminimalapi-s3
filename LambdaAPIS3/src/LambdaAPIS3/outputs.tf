output "lambda_function_arn" {
  value = aws_lambda_function.file_upload_lambda.arn
}

output "s3_bucket_url" {
  value = aws_s3_bucket.file_upload_bucket.website_endpoint
}