locals {
  handler_name = "bootstrap"
  source_dir   = "${path.module}/lambdas"
  s3_bucket    = var.lambdas_custom_s3_bucket != null ? var.lambdas_custom_s3_bucket : "weka-tf-aws-releases-${local.region}"
  s3_key       = var.lambdas_custom_s3_key != null ? var.lambdas_custom_s3_key : "${var.lambdas_dist}/${var.lambdas_version}.zip"
  functions = toset([
    "deploy", "clusterize", "report", "clusterize-finalization", "status", "scale-down", "fetch", "terminate",
    "transient", "join-nfs-finalization", "weka-api"
  ])
  enable_lambda_vpc = var.enable_lambda_vpc_config ? 1 : 0
  obs_prefix        = lookup(var.custom_prefix, "obs", var.prefix)
  lambda_prefix     = lookup(var.custom_prefix, "lambda", var.prefix)
  function_name     = [for func in local.functions : "${local.lambda_prefix}-${var.cluster_name}-${func}-lambda"]
  lambdas_hash = md5(join("", [
    for f in fileset(local.source_dir, "**") : filemd5("${local.source_dir}/${f}")
  ]))
  stripe_width_calculated = var.cluster_size - var.protection_level - 1
  stripe_width            = local.stripe_width_calculated < 16 ? local.stripe_width_calculated : 16
  install_weka_url        = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}?provider=aws&region=${data.aws_region.current.name}"
}

resource "aws_cloudwatch_log_group" "lambdas_log_group" {
  count             = length(local.function_name)
  name              = "/aws/lambda/${local.cloudwatch_prefix}/${local.function_name[count.index]}"
  retention_in_days = 30
  tags              = var.tags_map
}

resource "aws_lambda_function" "deploy_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-deploy-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA                            = "deploy"
      REGION                            = local.region
      TOKEN_ID                          = var.get_weka_io_token_secret_id != "" ? var.get_weka_io_token_secret_id : aws_secretsmanager_secret.get_weka_io_token[0].id
      STATE_TABLE                       = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY              = local.dynamodb_hash_key_name
      STATE_KEY                         = local.state_key
      NFS_STATE_KEY                     = local.nfs_state_key
      CLUSTER_NAME                      = var.cluster_name
      COMPUTE_MEMORY                    = var.set_dedicated_fe_container ? var.containers_config_map[var.instance_type].memory[1] : var.containers_config_map[var.instance_type].memory[0]
      COMPUTE_CONTAINER_CORES_NUM       = var.set_dedicated_fe_container ? var.containers_config_map[var.instance_type].compute : var.containers_config_map[var.instance_type].compute + 1
      FRONTEND_CONTAINER_CORES_NUM      = var.set_dedicated_fe_container ? var.containers_config_map[var.instance_type].frontend : 0
      DRIVE_CONTAINER_CORES_NUM         = var.containers_config_map[var.instance_type].drive
      INSTALL_URL                       = local.install_weka_url
      INSTALL_DPDK                      = var.install_cluster_dpdk
      NICS_NUM                          = var.containers_config_map[var.instance_type].nics
      CLUSTERIZE_LAMBDA_NAME            = aws_lambda_function.clusterize_lambda.function_name
      REPORT_LAMBDA_NAME                = aws_lambda_function.report_lambda.function_name
      FETCH_LAMBDA_NAME                 = aws_lambda_function.fetch_lambda.function_name
      STATUS_LAMBDA_NAME                = aws_lambda_function.status_lambda.function_name
      JOIN_NFS_FINALIZATION_LAMBDA_NAME = aws_lambda_function.join_nfs_finalization_lambda.function_name
      PROXY_URL                         = var.proxy_url
      NFS_INTERFACE_GROUP_NAME          = var.nfs_interface_group_name
      NFS_SECONDARY_IPS_NUM             = var.nfs_protocol_gateway_secondary_ips_per_nic
      NFS_PROTOCOL_GATEWAY_FE_CORES_NUM = var.nfs_protocol_gateway_fe_cores_num
      SMB_PROTOCOL_GATEWAY_FE_CORES_NUM = var.smb_protocol_gateway_fe_cores_num
      S3_PROTOCOL_GATEWAY_FE_CORES_NUM  = var.s3_protocol_gateway_fe_cores_num
      ALB_ARN_SUFFIX                    = var.create_alb ? aws_lb.alb[0].arn_suffix : ""
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]

  lifecycle {
    precondition {
      condition     = var.lambdas_dist == "release" || var.lambdas_version == local.lambdas_hash
      error_message = "Please update lambdas version."
    }
    precondition {
      condition     = var.install_weka_url != "" || var.weka_version != ""
      error_message = "Please provide either 'install_weka_url' or 'weka_version' variables."
    }
  }
}

resource "aws_lambda_function" "clusterize_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-clusterize-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA                       = "clusterize"
      REGION                       = local.region
      HOSTS_NUM                    = var.cluster_size
      CLUSTER_NAME                 = var.cluster_name
      PREFIX                       = local.obs_prefix
      NVMES_NUM                    = var.containers_config_map[var.instance_type].nvme
      ADMIN_PASSWORD_ID            = aws_secretsmanager_secret.weka_password.id
      DEPLOYMENT_PASSWORD_ID       = aws_secretsmanager_secret.weka_deployment_password.id
      STATE_TABLE                  = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY         = local.dynamodb_hash_key_name
      STATE_KEY                    = local.state_key
      NFS_STATE_KEY                = local.nfs_state_key
      STRIPE_WIDTH                 = var.stripe_width != -1 ? var.stripe_width : local.stripe_width
      PROTECTION_LEVEL             = var.protection_level
      HOTSPARE                     = var.hotspare
      SET_OBS                      = var.tiering_enable_obs_integration
      OBS_NAME                     = var.tiering_obs_name
      OBS_TIERING_SSD_PERCENT      = var.tiering_enable_ssd_percent
      TIERING_TARGET_SSD_RETENTION = var.tiering_obs_target_ssd_retention
      TIERING_START_DEMOTE         = var.tiering_obs_start_demote
      SET_DEFAULT_FS               = var.set_default_fs
      POST_CLUSTER_SETUP_SCRIPT    = var.post_cluster_setup_script
      FRONTEND_CONTAINER_CORES_NUM = var.set_dedicated_fe_container ? var.containers_config_map[var.instance_type].frontend : 0
      PROXY_URL                    = var.proxy_url
      CREATE_CONFIG_FS             = (var.smbw_enabled && var.smb_setup_protocol) || var.s3_setup_protocol
      WEKA_HOME_URL                = var.weka_home_url
      INSTALL_DPDK                 = var.install_cluster_dpdk
      # pass lambda function names
      CLUSTERIZE_FINALIZATION_LAMBDA_NAME = aws_lambda_function.clusterize_finalization_lambda.function_name
      REPORT_LAMBDA_NAME                  = aws_lambda_function.report_lambda.function_name
      FETCH_LAMBDA_NAME                   = aws_lambda_function.fetch_lambda.function_name
      NFS_INTERFACE_GROUP_NAME            = var.nfs_interface_group_name
      NFS_PROTOCOL_GATEWAYS_NUM           = var.nfs_protocol_gateways_number
      ALB_ARN_SUFFIX                      = var.create_alb ? aws_lb.alb[0].arn_suffix : ""
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "clusterize_finalization_lambda" {
  function_name = substr("${local.lambda_prefix}-${var.cluster_name}-clusterize-finalization-lambda", 0, 64)
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA               = "clusterizeFinalization"
      STATE_TABLE          = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY = local.dynamodb_hash_key_name
      STATE_KEY            = local.state_key
      NFS_STATE_KEY        = local.nfs_state_key
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "join_nfs_finalization_lambda" {
  function_name = substr("${local.lambda_prefix}-${var.cluster_name}-join-nfs-finalization-lambda", 0, 64)
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA = "joinNfsFinalization"
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}


resource "aws_lambda_function" "management" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-management-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  vpc_config {
    security_group_ids = local.sg_ids
    subnet_ids         = local.subnet_ids
  }
  environment {
    variables = {
      LAMBDA                     = "management"
      REGION                     = local.region
      CLUSTER_NAME               = var.cluster_name
      USERNAME_ID                = aws_secretsmanager_secret.weka_username.id
      DEPLOYMENT_PASSWORD_ID     = aws_secretsmanager_secret.weka_deployment_password.id
      ADMIN_PASSWORD_ID          = aws_secretsmanager_secret.weka_password.id
      USE_SECRETMANAGER_ENDPOINT = var.secretmanager_use_vpc_endpoint
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}


resource "aws_lambda_function" "report_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-report-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA               = "report"
      REGION               = local.region
      STATE_TABLE          = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY = local.dynamodb_hash_key_name
      STATE_KEY            = local.state_key
      NFS_STATE_KEY        = local.nfs_state_key
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "status_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-status-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA                     = "status"
      STATE_TABLE                = local.dynamodb_table_name
      STATE_TABLE_HASH_KEY       = local.dynamodb_hash_key_name
      STATE_KEY                  = local.state_key
      NFS_STATE_KEY              = local.nfs_state_key
      CLUSTER_NAME               = var.cluster_name
      WEKA_API_LAMBDA            = aws_lambda_function.weka_api.function_name
      MANAGEMENT_LAMBDA          = aws_lambda_function.management.function_name
      USERNAME_ID                = aws_secretsmanager_secret.weka_username.id
      DEPLOYMENT_PASSWORD_ID     = aws_secretsmanager_secret.weka_deployment_password.id
      ADMIN_PASSWORD_ID          = aws_secretsmanager_secret.weka_password.id
      USE_SECRETMANAGER_ENDPOINT = var.secretmanager_use_vpc_endpoint
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "weka_api" {
  function_name = "${var.prefix}-${var.cluster_name}-weka-api-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA                     = "weka-api"
      CLUSTER_NAME               = var.cluster_name
      MANAGEMENT_LAMBDA          = aws_lambda_function.management.function_name
      USERNAME_ID                = aws_secretsmanager_secret.weka_username.id
      DEPLOYMENT_PASSWORD_ID     = aws_secretsmanager_secret.weka_deployment_password.id
      ADMIN_PASSWORD_ID          = aws_secretsmanager_secret.weka_password.id
      USE_SECRETMANAGER_ENDPOINT = var.secretmanager_use_vpc_endpoint
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}


resource "aws_lambda_function" "fetch_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-fetch-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA                        = "fetch"
      REGION                        = local.region
      STATE_TABLE                   = local.dynamodb_table_name
      ROLE                          = "backend"
      DOWN_BACKENDS_REMOVAL_TIMEOUT = var.debug_down_backends_removal_timeout
      CLUSTER_NAME                  = var.cluster_name
      ASG_NAME                      = "${local.ec2_prefix}-${var.cluster_name}-autoscaling-group"
      NFS_ASG_NAME                  = "${local.ec2_prefix}-${var.cluster_name}-nfs-protocol-gateway"
      USERNAME_ID                   = aws_secretsmanager_secret.weka_username.id
      DEPLOYMENT_PASSWORD_ID        = aws_secretsmanager_secret.weka_deployment_password.id
      ADMIN_PASSWORD_ID             = aws_secretsmanager_secret.weka_password.id
      USE_SECRETMANAGER_ENDPOINT    = var.secretmanager_use_vpc_endpoint
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "scale_down_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-scale-down-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  vpc_config {
    security_group_ids = local.sg_ids
    subnet_ids         = local.subnet_ids
  }
  environment {
    variables = {
      LAMBDA                 = "scaleDown"
      REGION                 = local.region
      CLUSTER_NAME           = var.cluster_name
      USERNAME_ID            = aws_secretsmanager_secret.weka_username.id
      DEPLOYMENT_PASSWORD_ID = aws_secretsmanager_secret.weka_deployment_password.id
      ADMIN_PASSWORD_ID      = aws_secretsmanager_secret.weka_password.id
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "transient_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-transient-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA       = "transient"
      REGION       = local.region
      CLUSTER_NAME = var.cluster_name
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}

resource "aws_lambda_function" "terminate_lambda" {
  function_name = "${local.lambda_prefix}-${var.cluster_name}-terminate-lambda"
  s3_bucket     = local.s3_bucket
  s3_key        = local.s3_key
  handler       = local.handler_name
  role          = local.lambda_iam_role_arn
  memory_size   = 128
  timeout       = 20
  runtime       = "provided.al2"
  architectures = ["arm64"]
  dynamic "vpc_config" {
    for_each = range(0, local.enable_lambda_vpc)
    content {
      security_group_ids = local.sg_ids
      subnet_ids         = local.subnet_ids
    }
  }
  environment {
    variables = {
      LAMBDA       = "terminate"
      REGION       = local.region
      CLUSTER_NAME = var.cluster_name
      ASG_NAME     = "${local.ec2_prefix}-${var.cluster_name}-autoscaling-group"
      NFS_ASG_NAME = "${local.ec2_prefix}-${var.cluster_name}-nfs-protocol-gateway"
    }
  }
  tags       = var.tags_map
  depends_on = [aws_cloudwatch_log_group.lambdas_log_group]
}
