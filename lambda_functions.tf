data "aws_region" "current" {}

resource "aws_iam_role" "lambda_iam_role" {
  name = "${var.prefix}-${var.cluster_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name        = "${var.prefix}-${var.cluster_name}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = ["arn:aws:logs:*:*:*"]
    },{
      Effect = "Allow"
      Action = [
        "ec2:*"
      ]
      Resource = ["*"]
    }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
  role       = aws_iam_role.lambda_iam_role.name
}

data "archive_file" "lambda_archive_file" {
  type        = "zip"
  source_dir  = "${path.module}/cloud-functions/"
  output_path = "${path.module}/cloud-functions/functions.zip"
}

resource "aws_lambda_function" "clusterize_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-clusterize-lambda"
  filename         = "${path.module}/cloud-functions/functions.zip"
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = "functions"
  role             = aws_iam_role.lambda_iam_role.arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  vpc_config {
    subnet_ids         = [data.aws_subnet.subnets[0].id]
    security_group_ids = var.sg_id
  }
  environment {
    variables = {
      REGION = var.region
      TAG    = "${var.prefix}-${var.cluster_name}-backend"
      ASG_NAME = "${var.prefix}-${var.cluster_name}-autoscaling-group"
      ROLE = aws_iam_role.iam_role.name
      #PASSWORD = random_password.weka_password.result
      #TOKEN = var.get_weka_io_token
      BUCKET = var.obs_name
      COMPUTE_MEMORY = var.container_number_map[var.instance_type].memory
      NUM_COMPUTE_CONTAINERS = var.container_number_map[var.instance_type].compute
      NUM_FRONTEND_CONTAINERS = var.container_number_map[var.instance_type].frontend
      NUM_DRIVE_CONTAINERS = var.container_number_map[var.instance_type].drive
      INSTALL_URL = var.install_weka_url
      NICS_NUM = var.container_number_map[var.instance_type].nics
      INSTALL_DPDK = var.install_cluster_dpdk
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_api_gateway_resource" "gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "deploy"
}

resource "aws_api_gateway_rest_api" "rest_api" {
  name = "${var.prefix}-${var.cluster_name}-rest-api"
}

resource "aws_api_gateway_method" "gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.gateway_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway ------> Lambda
resource "aws_api_gateway_integration" "gateway_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.gateway_resource.id
  http_method             = aws_api_gateway_method.gateway_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.clusterize_lambda.arn}/invocations"
}

# This resource defines the URL of the API Gateway.
resource "aws_api_gateway_deployment" "gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  stage_name  = "v1"
  depends_on  = [aws_api_gateway_integration.gateway_integration ]
}

# Set the generated URL as an output. Run `terraform output url` to get this.
output "url" {
  value = "${aws_api_gateway_deployment.gateway_deployment.invoke_url}${aws_api_gateway_resource.gateway_resource.path}"
}