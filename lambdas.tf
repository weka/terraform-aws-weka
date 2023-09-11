locals {
  handler_name = "lambdas"
  source_dir   = "${path.module}/${local.handler_name}"
  s3_bucket    = "weka-tf-aws-releases-${local.region}"
  s3_key       = "${var.lambdas_dist}/${var.lambdas_version}.zip"
  functions = toset([
    "deploy", "clusterize", "report", "clusterize-finalization", "status", "scale-down", "fetch", "terminate",
    "transient"
  ])
  function_name           = [for func in local.functions : "${var.prefix}-${var.cluster_name}-${func}-lambda"]
  lambdas_hash            = md5(join("", [for f in fileset(local.source_dir, "**") : filemd5("${local.source_dir}/${f}")]))
  stripe_width_calculated = var.cluster_size - var.protection_level - 1
  stripe_width            = local.stripe_width_calculated < 16 ? local.stripe_width_calculated : 16
  install_weka_url        = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
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
  handler       = local.handler_name
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
      COMPUTE_MEMORY          = var.add_frontend_container ? var.container_number_map[var.instance_type].memory[1] : var.container_number_map[var.instance_type].memory[0]
      NUM_COMPUTE_CONTAINERS  = var.add_frontend_container ? var.container_number_map[var.instance_type].compute : var.container_number_map[var.instance_type].compute + 1
      NUM_FRONTEND_CONTAINERS = var.add_frontend_container ? var.container_number_map[var.instance_type].frontend : 0
      NUM_DRIVE_CONTAINERS    = var.container_number_map[var.instance_type].drive
      INSTALL_URL             = local.install_weka_url
      NICS_NUM                = var.container_number_map[var.instance_type].nics
      CLUSTERIZE_LAMBDA_NAME  = aws_lambda_function.clusterize_lambda.function_name
      REPORT_LAMBDA_NAME      = aws_lambda_function.report_lambda.function_name
      PROXY_URL               = var.proxy_url
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]

  lifecycle {
    precondition {
      condition     = var.lambdas_version == local.lambdas_hash
      error_message = "Please update lambdas version."
    }
  }
}

resource "aws_lambda_function" "clusterize_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-clusterize-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA                  = "clusterize"
      REGION                  = local.region
      HOSTS_NUM               = var.cluster_size
      CLUSTER_NAME            = var.cluster_name
      PREFIX                  = var.prefix
      NVMES_NUM               = var.container_number_map[var.instance_type].nvme
      USERNAME_ID             = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID             = aws_secretsmanager_secret.weka_password.id
      STATE_TABLE             = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY    = local.dynamodb_hash_key_name
      STRIPE_WIDTH            = var.stripe_width != -1 ? var.stripe_width : local.stripe_width
      PROTECTION_LEVEL        = var.protection_level
      HOTSPARE                = var.hotspare
      SET_OBS                 = var.set_obs_integration
      OBS_NAME                = var.obs_name
      OBS_TIERING_SSD_PERCENT = var.tiering_ssd_percent
      NUM_FRONTEND_CONTAINERS = var.add_frontend_container ? var.container_number_map[var.instance_type].frontend : 0
      PROXY_URL               = var.proxy_url
      SMBW_ENABLED            = var.smbw_enabled
      # pass lambda function names
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
  handler       = local.handler_name
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
  handler       = local.handler_name
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
  handler       = local.handler_name
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
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "fetch_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-fetch-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA                     = "fetch"
      REGION                     = local.region
      STATE_TABLE                = local.dynamodb_table_name
      ROLE                       = "backend"
      PREFIX                     = var.prefix
      CLUSTER_NAME               = var.cluster_name
      ASG_NAME                   = "${var.prefix}-${var.cluster_name}-autoscaling-group"
      USERNAME_ID                = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID                = aws_secretsmanager_secret.weka_password.id
      USE_SECRETMANAGER_ENDPOINT = var.use_secretmanager_endpoint
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "scale_down_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-scale-down-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  vpc_config {
    security_group_ids = local.sg_ids
    subnet_ids         = local.subnet_ids
  }
  environment {
    variables = {
      LAMBDA       = "scaleDown"
      REGION       = local.region
      PREFIX       = var.prefix
      CLUSTER_NAME = var.cluster_name
      USERNAME_ID  = aws_secretsmanager_secret.weka_username.id
      PASSWORD_ID  = aws_secretsmanager_secret.weka_password.id
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "transient_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-transient-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA       = "transient"
      REGION       = local.region
      PREFIX       = var.prefix
      CLUSTER_NAME = var.cluster_name
    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}

resource "aws_lambda_function" "terminate_lambda" {
  function_name = "${var.prefix}-${var.cluster_name}-terminate-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "go1.x"
  environment {
    variables = {
      LAMBDA       = "terminate"
      REGION       = local.region
      PREFIX       = var.prefix
      CLUSTER_NAME = var.cluster_name
      ASG_NAME     = "${var.prefix}-${var.cluster_name}-autoscaling-group"

    }
  }
  depends_on = [aws_cloudwatch_log_group.cloudwatch_log_group]
}
