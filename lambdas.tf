locals {
  binary_name = "lambdas"
  binary_path = "${path.module}/lambdas/${local.binary_name}"
  source_dir  = "${path.module}/lambdas"
  s3_bucket   = "tf-lambdas-${local.region}"
  s3_key      = "${var.lambdas_dist}/${var.lambdas_version}.zip"
  functions     = toset(["deploy","clusterize","report","clusterize-finalization","status"])
  function_name = [for func in local.functions: "${var.prefix}-${var.cluster_name}-${func}-lambda"]
}

resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  count             = length(local.function_name)
  name              = "/aws/lambda/${local.function_name[count.index]}"
  retention_in_days = 30
}

resource "aws_lambda_function" "deploy_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-deploy-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.binary_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA                  = "deploy"
      REGION                  = local.region
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
      INSTALL_URL             = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}?provider=aws&region=${local.region}"
      NICS_NUM                = var.container_number_map[var.instance_type].nics
      CLUSTERIZE_LAMBDA_NAME  = aws_lambda_function.clusterize_lambda.function_name
      REPORT_LAMBDA_NAME      = aws_lambda_function.report_lambda.function_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "clusterize_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-clusterize-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.binary_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA                      = "clusterize"
      REGION                      = local.region
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
      // pass lambda function names
      CLUSTERIZE_FINALIZATION_LAMBDA_NAME = aws_lambda_function.clusterize_finalization_lambda.function_name
      REPORT_LAMBDA_NAME                  = aws_lambda_function.report_lambda.function_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "clusterize_finalization_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-clusterize-finalization-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.binary_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA               = "clusterizeFinalization"
      REGION               = local.region
      STATE_TABLE          = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY = local.dynamodb_hash_key_name
      PREFIX               = var.prefix
      CLUSTER_NAME         = var.cluster_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "report_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-report-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.binary_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA               = "report"
      REGION               = local.region
      STATE_TABLE          = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY = local.dynamodb_hash_key_name
      PREFIX               = var.prefix
      CLUSTER_NAME         = var.cluster_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "status_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-status-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.binary_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA               = "status"
      REGION               = local.region
      STATE_TABLE          = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY = local.dynamodb_hash_key_name
      PREFIX               = var.prefix
      CLUSTER_NAME         = var.cluster_name
      //USERNAME_ID = aws_secretsmanager_secret.weka_username.id
      //PASSWORD_ID = aws_secretsmanager_secret.weka_password.id
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}