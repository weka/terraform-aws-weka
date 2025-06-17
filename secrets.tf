resource "random_password" "suffix" {
  length      = 4
  lower       = true
  min_lower   = 1
  upper       = true
  min_upper   = 1
  numeric     = true
  min_numeric = 1
  special     = false
}

locals {
  prefix             = lookup(var.custom_prefix, "secrets", "weka/${var.prefix}")
  secret_prefix      = "${local.prefix}-${var.cluster_name}/"
  secrets_kms_key_id = local.create_secrets_kms_key ? module.secrets_kms[0].arn : var.secretmanager_kms_key_id
}

resource "aws_secretsmanager_secret" "get_weka_io_token" {
  count      = var.get_weka_io_token_secret_id == "" ? 1 : 0
  name       = "${local.secret_prefix}get_weka_io_token-${random_password.suffix.result}"
  kms_key_id = local.secrets_kms_key_id
  tags       = var.tags_map
}

resource "aws_secretsmanager_secret_version" "get_weka_io_token" {
  count         = var.get_weka_io_token_secret_id == "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.get_weka_io_token[0].id
  secret_string = var.get_weka_io_token
}

resource "aws_secretsmanager_secret" "weka_username" {
  name       = "${local.secret_prefix}weka-username-${random_password.suffix.result}"
  kms_key_id = local.secrets_kms_key_id
  tags       = var.tags_map
}

resource "aws_secretsmanager_secret_version" "weka_username" {
  secret_id     = aws_secretsmanager_secret.weka_username.id
  secret_string = "weka-deployment"
}

resource "aws_secretsmanager_secret" "weka_password" {
  name       = "${local.secret_prefix}weka-password-${random_password.suffix.result}"
  kms_key_id = local.secrets_kms_key_id
  tags       = var.tags_map
}

resource "aws_secretsmanager_secret" "weka_deployment_password" {
  name       = "${local.secret_prefix}weka-deployment-password-${random_password.suffix.result}"
  kms_key_id = local.secrets_kms_key_id
  tags       = var.tags_map
}

resource "aws_secretsmanager_secret" "self_signed_certificate_private_key" {
  count      = local.create_self_signed_certificate ? 1 : 0
  name       = "${local.secret_prefix}self-signed-cert-pem-${random_password.suffix.result}"
  kms_key_id = local.secrets_kms_key_id
  tags       = var.tags_map
}

resource "aws_secretsmanager_secret_version" "self_signed_certificate_private_key" {
  count         = local.create_self_signed_certificate ? 1 : 0
  secret_id     = aws_secretsmanager_secret.self_signed_certificate_private_key[0].id
  secret_string = module.self_signed_certificate[0].cert_pem
}
