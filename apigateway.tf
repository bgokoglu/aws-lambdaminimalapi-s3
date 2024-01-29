# https://advancedweb.hu/how-to-use-the-aws_apigatewayv2_api-to-add-an-http-api-to-a-lambda-function/
# Create API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api_gw" {
  name          = "ei-bg-apigw"
  protocol_type = "HTTP"
  target        = aws_lambda_function.file_upload_lambda.arn
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "HEAD", "OPTIONS", "POST"]
  }
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "dev" {
  api_id      = aws_apigatewayv2_api.http_api_gw.id
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

# Create Lambda function permission for API Gateway
resource "aws_lambda_permission" "function_resource_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api_gw.execution_arn}/*/*"
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