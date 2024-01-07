terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
}


# DynamoDB table for data
resource "aws_dynamodb_table" "table" {
  name = "items"
  hash_key = "id"  
  attribute  {
      name = "id"
      type = "S"
    }
  billing_mode = "PAY_PER_REQUEST"
}

# IAM role and policy for Lambda 
data "aws_iam_policy_document" "lambda_policy_doc" {
  statement {
    actions = ["dynamodb:*"]    
    resources = ["${aws_dynamodb_table.table.arn}"]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "serverless_lambda_policy"
  role = aws_iam_role.lambda_exec_role.id
  policy = data.aws_iam_policy_document.lambda_policy_doc.json
}

# Lambda functions
resource "aws_lambda_function" "create_func" {
   function_name = "CreateItem"
   filename = "create_item.zip"
   runtime = "python3.8"
   handler = "create.handler"
   role = aws_iam_role.lambda_exec_role.arn
}

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
 name = "ServerlessCrudAPI"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "item"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_func.invoke_arn
}
