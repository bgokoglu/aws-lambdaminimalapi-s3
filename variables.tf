variable "lambda_execution_role_name" {
  type    = string
  default = "ei_bg_api_lambda_execution_role"
}

variable "s3_file_upload_bucket_name" {
  type    = string
  default = "ei-bg-api-file-upload"
}

variable "s3_lambda_bucket_name" {
  type    = string
  default = "ei-bg-api-lambda-bucket"
}