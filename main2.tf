# Criar um bucket S3 para armazenamento de logs
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs"
}

# Criar uma tabela DynamoDB para armazenar URLs
resource "aws_dynamodb_table" "url_table" {
  name         = "${var.project_name}-table"
  hash_key     = "short_url"

  attribute {
    name = "short_url"
    type = "S"
  }

  read_capacity  = 1
  write_capacity = 1
}

# Criar uma função Lambda para a lógica de encurtamento de URLs
resource "aws_lambda_function" "shortener" {
  filename         = "lambda.zip"
  function_name    = "${var.project_name}-shortener"
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  role             = aws_iam_role.lambda_exec.arn
}

# Criar um API Gateway
resource "aws_api_gateway_rest_api" "url_api" {
  name        = "${var.project_name}-api"
  description = "API for URL shortener"
}

resource "aws_api_gateway_resource" "url_resource" {
  rest_api_id = aws_api_gateway_rest_api.url_api.id
  parent_id   = aws_api_gateway_rest_api.url_api.root_resource_id
  path_part   = "urls"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.url_api.id
  resource_id   = aws_api_gateway_resource.url_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.url_api.id
  resource_id = aws_api_gateway_resource.url_resource.id
  http_method = aws_api_gateway_method.post_method.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.shortener.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shortener.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.url_api.execution_arn}/*/*"
}

output "api_url" {
  value = "${aws_api_gateway_rest_api.url_api.execution_arn}/urls"
}
