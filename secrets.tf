resource "random_password" "suffix" {
  length  = 4
  lower   = true
  min_lower = 1
  upper   = true
  min_upper = 1
  numeric = true
  min_numeric = 1
  special = false
}

resource "aws_secretsmanager_secret" "get_weka_io_token" {
  name = "${var.prefix}-${var.cluster_name}-get_weka_io_token-${random_password.suffix.result}"
}

resource "aws_secretsmanager_secret_version" "get_weka_io_token" {
  secret_id     = aws_secretsmanager_secret.get_weka_io_token.id
  secret_string = var.get_weka_io_token
}

resource "aws_secretsmanager_secret" "weka_username" {
  name = "${var.prefix}-${var.cluster_name}-weka-username-${random_password.suffix.result}"
}

resource "aws_secretsmanager_secret_version" "weka_username" {
  secret_id     = aws_secretsmanager_secret.weka_username.id
  secret_string = var.weka_username
}

resource "random_password" "password" {
  length  = 16
  lower   = true
  min_lower = 1
  upper   = true
  min_upper = 1
  numeric = true
  min_numeric = 1
  special = false
}

resource "aws_secretsmanager_secret" "weka_password" {
  name = "${var.prefix}-${var.cluster_name}-weka-password-${random_password.suffix.result}"
}

resource "aws_secretsmanager_secret_version" "weka_password" {
  secret_id     = aws_secretsmanager_secret.weka_password.id
  secret_string = random_password.password.result
}
