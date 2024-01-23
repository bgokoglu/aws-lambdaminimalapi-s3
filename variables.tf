variable "lambda_execution_role_name" {
  type    = string
  default = "ei_bg_lambda_execution_role"
}

variable "s3_file_upload_bucket_name" {
  type    = string
  default = "ei-bg-file-upload"
}

variable "s3_lambda_bucket_name" {
  type    = string
  default = "ei-bg-lambda"
}

