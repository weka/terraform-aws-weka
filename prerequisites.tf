data "aws_region" "current" {}

locals {
  region                         = data.aws_region.current.region
  create_secrets_kms_key         = var.secretmanager_enable_encryption && var.secretmanager_kms_key_id == null
  kms_prefix                     = lookup(var.custom_prefix, "kms", var.prefix)
  create_self_signed_certificate = var.create_alb && var.alb_cert_arn == null
}

module "network" {
  count                            = length(var.subnet_ids) == 0 ? 1 : 0
  source                           = "./modules/network"
  prefix                           = var.prefix
  availability_zones               = var.availability_zones
  subnet_autocreate_as_private     = var.subnet_autocreate_as_private
  additional_subnet                = var.create_alb
  subnets_cidrs                    = var.subnets_cidrs
  nat_public_subnet_cidr           = var.nat_public_subnet_cidr
  alb_additional_subnet_cidr_block = var.alb_additional_subnet_cidr_block
  alb_additional_subnet_zone       = var.alb_additional_subnet_zone
  create_nat_gateway               = var.create_nat_gateway
  vpc_cidr                         = var.vpc_cidr
  tags_map                         = var.tags_map
}

module "security_group" {
  count                 = length(var.sg_ids) == 0 ? 1 : 0
  source                = "./modules/security_group"
  prefix                = var.prefix
  cluster_name          = var.cluster_name
  vpc_id                = local.vpc_id
  allow_ssh_cidrs       = var.allow_ssh_cidrs
  alb_allow_https_cidrs = var.alb_allow_https_cidrs
  allow_weka_api_cidrs  = var.allow_weka_api_cidrs
  tags_map              = var.tags_map
  custom_ingress_rules  = var.sg_custom_ingress_rules
  depends_on            = [module.network]
}

module "iam" {
  count                           = var.instance_iam_profile_arn == "" ? 1 : 0
  source                          = "./modules/iam"
  prefix                          = var.prefix
  custom_prefix                   = var.custom_prefix
  cluster_name                    = var.cluster_name
  tags_map                        = var.tags_map
  state_table_name                = local.dynamodb_table_name
  tiering_obs_name                = var.tiering_obs_iam_bucket_prefix != "" ? var.tiering_obs_iam_bucket_prefix : var.tiering_obs_name
  secret_prefix                   = local.secret_prefix
  tiering_enable_obs_integration  = var.tiering_enable_obs_integration
  additional_iam_policy_statement = var.additional_instance_iam_policy_statement
}

module "vpc_endpoint" {
  count                                = var.vpc_endpoint_ec2_create || var.vpc_endpoint_proxy_create || var.vpc_endpoint_s3_gateway_create ? 1 : 0
  source                               = "./modules/endpoint"
  region                               = data.aws_region.current.region
  create_vpc_endpoint_ec2              = var.vpc_endpoint_ec2_create
  create_vpc_endpoint_s3_gateway       = var.vpc_endpoint_s3_gateway_create
  create_vpc_endpoint_proxy            = var.vpc_endpoint_proxy_create
  create_vpc_endpoint_lambda           = var.vpc_endpoint_lambda_create
  create_vpc_endpoint_dynamodb_gateway = var.vpc_endpoint_dynamodb_gateway_create
  create_vpc_endpoint_autoscaling      = var.vpc_endpoint_autoscaling_create
  prefix                               = var.prefix
  vpc_id                               = local.vpc_id
  subnet_id                            = local.subnet_ids[0]
  tags_map                             = var.tags_map
  depends_on                           = [module.network, module.security_group]
}

# We should move the ebs kms key creation to be handled by the kms module, but it will cause re-creation of the kms key
# For now keeping the old ebs kms setup
# module "ebs_kms" {
#   count     = local.create_ebs_kms_key ? 1 : 0
#   source    = "./modules/kms"
#   name      = "${local.kms_prefix}-${var.cluster_name}"
#   principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
#   tags_map  = var.tags_map
# }

module "secrets_kms" {
  count      = local.create_secrets_kms_key ? 1 : 0
  source     = "./modules/kms"
  name       = "${local.kms_prefix}-${var.cluster_name}-secrets"
  principal  = local.lambda_iam_role_arn
  tags_map   = var.tags_map
  depends_on = [module.iam]
}

module "self_signed_certificate" {
  count        = local.create_self_signed_certificate ? 1 : 0
  source       = "./modules/self_signed_certificate"
  common_name  = "*.${local.region}.elb.amazonaws.com"
  organization = "Weka Cluster Self-signed CA"
  tags         = var.tags_map
}

locals {
  subnet_ids                    = length(var.subnet_ids) == 0 && length(module.network) > 0 ? module.network[0].subnet_ids : var.subnet_ids
  alb_subnet_id                 = var.alb_subnet_id != "" ? var.alb_subnet_id : length(var.subnet_ids) == 0 && length(module.network) > 0 ? module.network[0].subnet_ids[0] : var.subnet_ids[0]
  additional_subnet_id          = var.create_alb ? var.alb_additional_subnet_id == "" ? module.network[0].additional_subnet_id : var.alb_additional_subnet_id : ""
  vpc_id                        = length(var.subnet_ids) == 0 ? module.network[0].vpc_id : data.aws_subnet.this[0].vpc_id
  sg_ids                        = length(var.sg_ids) == 0 && length(module.security_group) > 0 ? module.security_group[0].sg_ids : var.sg_ids
  alb_sg_ids                    = var.create_alb ? length(var.alb_sg_ids) > 0 ? var.alb_sg_ids : local.sg_ids : []
  instance_iam_profile_arn      = var.instance_iam_profile_arn == "" ? module.iam[0].instance_iam_profile_arn : var.instance_iam_profile_arn
  lambda_iam_role_arn           = var.lambda_iam_role_arn == "" ? module.iam[0].lambda_iam_role_arn : var.lambda_iam_role_arn
  sfn_iam_role_arn              = var.sfn_iam_role_arn == "" ? module.iam[0].sfn_iam_role_arn : var.sfn_iam_role_arn
  event_iam_role_arn            = var.event_iam_role_arn == "" ? module.iam[0].event_iam_role_arn : var.event_iam_role_arn
  secretmanager_endpoint_sg_ids = length(var.secretmanager_sg_ids) > 1 ? var.secretmanager_sg_ids : local.sg_ids
  assign_public_ip              = var.assign_public_ip != "auto" ? var.assign_public_ip == "true" : length(var.subnet_ids) == 0
}

# endpoint to secret manager
resource "aws_vpc_endpoint" "secretmanager_endpoint" {
  count               = var.secretmanager_use_vpc_endpoint && var.secretmanager_create_vpc_endpoint ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = local.secretmanager_endpoint_sg_ids
  subnet_ids          = local.subnet_ids
  private_dns_enabled = true
  tags = merge(var.tags_map, {
    Name        = "${var.prefix}-secretmanager-endpoint"
    Environment = var.prefix
  })
  depends_on = [module.network]
}
