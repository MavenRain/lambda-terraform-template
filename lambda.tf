locals {
  artifact-acl = "public-read"
  artifact-bucket = "oni-lambda-deploy"
  artifact-key = "lambda-con.zip"
}

provider "aws" {
  region = "eu-west-1"
}

data "archive_file" "lambda-con" {
  type = "zip"
  source_dir = "./source"
  output_path = "${local.artifact-key}"
}

resource "aws_s3_bucket" "mojave" {
  bucket = "${local.artifact-bucket}"
  acl    = "${local.artifact-acl}"
}

resource "aws_s3_bucket_object" "object" {
  acl = "${local.artifact-acl}"
  bucket = "${aws_s3_bucket.mojave.bucket}"
  key = "${local.artifact-key}"
  source = "./${local.artifact-key}"
  etag = "${md5(file("./${local.artifact-key}"))}"
  content_type = "application/octet-stream"
}

resource "aws_lambda_function" "lambda-test" {
  s3_bucket = "${aws_s3_bucket.mojave.bucket}"
  s3_key = "${local.artifact-key}"
  function_name = "lambda-test"
  role = "${aws_iam_role.lambda-role.arn}"
  handler = "index.handler"
  source_code_hash = "${data.archive_file.lambda-con.output_base64sha256}"
  runtime = "nodejs6.10"
  depends_on = ["aws_s3_bucket_object.object"]
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
