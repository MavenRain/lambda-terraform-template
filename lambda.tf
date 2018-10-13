locals {
  lambda-file = "lambda-con.zip"
}

provider "aws" {
  region = "us-west-2"
}

data "archive_file" "lambda-con" {
  type = "zip"
  source_file = "index.js"
  output_path = "${local.lambda-file}"
}

resource "aws_lambda_function" "lambda-test" {
  filename = "${local.lambda-file}"
  function_name = "lambda-test"
  role = "${aws_iam_role.lambda-role.arn}"
  handler = "index.handler"
  source_code_hash = "${data.archive_file.lambda-con.output_base64sha256}"
  runtime = "nodejs6.10"
}

resource "aws_iam_role" "lambda-role" {
  name = "lambda-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_api_gateway_rest_api" "sample" {
  name = "Lambda-Example"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.sample.id}"
  parent_id = "${aws_api_gateway_rest_api.sample.root_resource_id}"
  path_part = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.sample.id}"
  resource_id = "${aws_api_gateway_resource.proxy.id}"
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "root" {
  rest_api_id = "${aws_api_gateway_rest_api.sample.id}"
  resource_id = "${aws_api_gateway_rest_api.sample.root_resource_id}"
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.sample.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.lambda-test.invoke_arn}"
}

resource "aws_api_gateway_integration" "lambda-root" {
  rest_api_id = "${aws_api_gateway_rest_api.sample.id}"
  resource_id = "${aws_api_gateway_method.root.resource_id}"
  http_method = "${aws_api_gateway_method.root.http_method}"
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = "${aws_lambda_function.lambda-test.invoke_arn}"
}

resource "aws_api_gateway_deployment" "sample" {
  depends_on = [
    "aws_api_gateway_integration.lambda",
    "aws_api_gateway_integration.lambda-root",
  ]
  stage_name = "test"
  rest_api_id = "${aws_api_gateway_rest_api.sample.id}"
}

resource "aws_lambda_permission" "gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda-test.arn}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.sample.execution_arn}/*/*"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.sample.invoke_url}"
}