data "aws_region" "current" {}

resource "aws_iam_role" "lambda_iam_role" {
  name               = "${var.prefix}-${var.cluster_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name   = "${var.prefix}-${var.cluster_name}-lambda-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }, {
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
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

locals {
  binary_name = "lambdas"
  binary_path = "${path.module}/lambdas/${local.binary_name}"
  source_dir  = "${path.module}/lambdas"
  lambda_zip  = "${local.source_dir}/${local.binary_name}.zip"
}

resource "null_resource" "function_binary" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "GOOS=linux GOARCH=amd64 CGO_ENABLED=0 GOFLAGS=-trimpath go build -C ${local.source_dir} -o ${local.binary_name} "
  }
}

data "archive_file" "lambda_archive_file" {
  type        = "zip"
  source_file = local.binary_path
  output_path = local.lambda_zip
  depends_on  = [null_resource.function_binary]
}

resource "aws_lambda_function" "deploy_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-deploy-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = aws_iam_role.lambda_iam_role.arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA                  = "deploy"
      REGION                  = var.region
      USER_NAME_ID            = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID             = aws_secretsmanager_secret.weka_password.id
      TOKEN_ID                = aws_secretsmanager_secret.get_weka_io_token.id
      BUCKET                  = local.state_bucket_name
      CLUSTER_NAME            = var.cluster_name
      COMPUTE_MEMORY          = var.container_number_map[var.instance_type].memory
      NUM_COMPUTE_CONTAINERS  = var.container_number_map[var.instance_type].compute
      NUM_FRONTEND_CONTAINERS = var.container_number_map[var.instance_type].frontend
      NUM_DRIVE_CONTAINERS    = var.container_number_map[var.instance_type].drive
      INSTALL_URL             = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
      NICS_NUM                = var.container_number_map[var.instance_type].nics
      CLUSTERIZE_URL          = aws_lambda_function_url.clusterize_lambda_url.function_url
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function" "clusterize_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-clusterize-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = aws_iam_role.lambda_iam_role.arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA                      = "clusterize"
      REGION                      = var.region
      HOSTS_NUM                   = var.cluster_size
      CLUSTER_NAME                = var.cluster_name
      PREFIX                      = var.prefix
      NVMES_NUM                   = var.container_number_map[var.instance_type].nvme
      USER_NAME_ID                = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID                 = aws_secretsmanager_secret.weka_password.id
      BUCKET                      = local.state_bucket_name
      STRIPE_WIDTH                = var.stripe_width
      PROTECTION_LEVEL            = var.protection_level
      HOTSPARE                    = var.hotspare
      SET_OBS                     = var.set_obs_integration
      OBS_TIERING_SSD_PERCENT     = var.tiering_ssd_percent
      NUM_FRONTEND_CONTAINERS     = var.container_number_map[var.instance_type].frontend
      CLUSTERIZE_FINALIZATION_URL = aws_lambda_function_url.clusterize_finalization_lambda_url.function_url
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function" "clusterize_finalization_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-clusterize-finalization-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = aws_iam_role.lambda_iam_role.arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA = "clusterizeFinalization"
      REGION = var.region
      BUCKET = local.state_bucket_name
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function_url" "deploy_lambda_url" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.deploy_lambda.function_name
}

resource "aws_lambda_function_url" "clusterize_lambda_url" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.clusterize_lambda.function_name
}

resource "aws_lambda_function_url" "clusterize_finalization_lambda_url" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.clusterize_finalization_lambda.function_name
}
