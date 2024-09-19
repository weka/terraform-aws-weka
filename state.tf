locals {
  dynamodb_table_name    = var.dynamodb_table_name == "" ? aws_dynamodb_table.weka_deployment[0].name : var.dynamodb_table_name
  dynamodb_hash_key_name = var.dynamodb_hash_key_name == "" ? "Key" : var.dynamodb_hash_key_name
  db_prefix              = lookup(var.custom_prefix, "db", var.prefix)
  state_key              = "${var.prefix}-${var.cluster_name}-state"
  nfs_state_key          = "${var.prefix}-${var.cluster_name}-nfs-state"
}

resource "aws_dynamodb_table" "weka_deployment" {
  count = var.dynamodb_table_name == "" ? 1 : 0

  name         = "${local.db_prefix}-${var.cluster_name}-weka-deployment"
  hash_key     = local.dynamodb_hash_key_name
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = local.dynamodb_hash_key_name
    type = "S"
  }
  tags = var.tags_map
}

resource "aws_dynamodb_table_item" "weka_deployment_state" {
  table_name = local.dynamodb_table_name
  hash_key   = local.dynamodb_hash_key_name

  item = <<ITEM
{
  "${local.dynamodb_hash_key_name}": {"S": "${local.state_key}"},
  "Locked": {"BOOL": false},
  "Value": {"M": {
    "initial_size": {"N": "${var.cluster_size}"},
    "desired_size": {"N": "${var.cluster_size}"},
    "clusterization_target": {"N": "${var.cluster_size}"},
    "instances": {"L": []},
    "clusterized": {"BOOL": false}
  }}
}
ITEM

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_dynamodb_table_item" "weka_deployment_nfs_state" {
  count      = var.nfs_protocol_gateways_number > 0 ? 1 : 0
  table_name = local.dynamodb_table_name
  hash_key   = local.dynamodb_hash_key_name

  item = <<ITEM
{
  "${local.dynamodb_hash_key_name}": {"S": "${local.nfs_state_key}"},
  "Locked": {"BOOL": false},
  "Value": {"M": {
    "initial_size": {"N": "${var.nfs_protocol_gateways_number}"},
    "desired_size": {"N": "${var.nfs_protocol_gateways_number}"},
    "clusterization_target": {"N": "${var.nfs_protocol_gateways_number}"},
    "instances": {"L": []},
    "clusterized": {"BOOL": false}
  }}
}
ITEM

  lifecycle {
    ignore_changes = all
  }
}
