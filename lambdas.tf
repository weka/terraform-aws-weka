data "aws_region" "current" {}

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
  role             = local.lambda_iam_role_arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA                  = "deploy"
      REGION                  = var.region
      USERNAME_ID             = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID             = aws_secretsmanager_secret.weka_password.id
      TOKEN_ID                = aws_secretsmanager_secret.get_weka_io_token.id
      STATE_TABLE             = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY    = local.dynamodb_hash_key_name
      PREFIX                  = var.prefix
      CLUSTER_NAME            = var.cluster_name
      COMPUTE_MEMORY          = var.container_number_map[var.instance_type].memory
      NUM_COMPUTE_CONTAINERS  = var.container_number_map[var.instance_type].compute
      NUM_FRONTEND_CONTAINERS = var.container_number_map[var.instance_type].frontend
      NUM_DRIVE_CONTAINERS    = var.container_number_map[var.instance_type].drive
      INSTALL_URL             = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
      NICS_NUM                = var.container_number_map[var.instance_type].nics
      CLUSTERIZE_URL          = aws_lambda_function_url.clusterize_lambda_url.function_url
      REPORT_URL              = aws_lambda_function_url.report_lambda_url.function_url
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function" "clusterize_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-clusterize-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = local.lambda_iam_role_arn
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
      USERNAME_ID                 = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID                 = aws_secretsmanager_secret.weka_password.id
      STATE_TABLE                 = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY        = local.dynamodb_hash_key_name
      STRIPE_WIDTH                = var.stripe_width
      PROTECTION_LEVEL            = var.protection_level
      HOTSPARE                    = var.hotspare
      SET_OBS                     = var.set_obs_integration
      OBS_NAME                    = var.obs_name
      OBS_TIERING_SSD_PERCENT     = var.tiering_ssd_percent
      NUM_FRONTEND_CONTAINERS     = var.container_number_map[var.instance_type].frontend
      PROXY_URL                   = var.proxy_url
      CLUSTERIZE_FINALIZATION_URL = aws_lambda_function_url.clusterize_finalization_lambda_url.function_url
      REPORT_URL                  = aws_lambda_function_url.report_lambda_url.function_url
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function" "clusterize_finalization_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-clusterize-finalization-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = local.lambda_iam_role_arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA               = "clusterizeFinalization"
      REGION               = var.region
      STATE_TABLE          = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY = local.dynamodb_hash_key_name
      PREFIX               = var.prefix
      CLUSTER_NAME         = var.cluster_name
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function" "report_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-report-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = local.lambda_iam_role_arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA = "report"
      REGION = var.region
      STATE_TABLE             = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY    = local.dynamodb_hash_key_name
      PREFIX                  = var.prefix
      CLUSTER_NAME            = var.cluster_name
    }
  }
  depends_on = [data.archive_file.lambda_archive_file]
}

resource "aws_lambda_function" "status_lambda" {
  function_name    = "${var.prefix}-${var.cluster_name}-status-lambda"
  filename         = local.lambda_zip
  source_code_hash = data.archive_file.lambda_archive_file.output_base64sha256
  handler          = local.binary_name
  role             = local.lambda_iam_role_arn
  memory_size      = 128
  timeout          = 20
  runtime          = "go1.x"
  environment {
    variables = {
      LAMBDA = "status"
      REGION = var.region
      STATE_TABLE             = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY    = local.dynamodb_hash_key_name
      PREFIX                  = var.prefix
      CLUSTER_NAME            = var.cluster_name
      //USERNAME_ID = aws_secretsmanager_secret.weka_username.id
      //PASSWORD_ID = aws_secretsmanager_secret.weka_password.id
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

resource "aws_lambda_function_url" "report_lambda_url" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.report_lambda.function_name
}

resource "aws_lambda_function_url" "status_lambda_url" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.status_lambda.function_name
}
