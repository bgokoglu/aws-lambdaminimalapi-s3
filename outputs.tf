output "lambda_function_url" {
  value = aws_lambda_function_url.test_latest.function_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.file_upload_bucket.id
}

output "file_upload_topic" {
  value = aws_sns_topic.file_upload_topic.arn
}