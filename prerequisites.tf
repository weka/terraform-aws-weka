data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
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
  create_nat_gateway               = var.create_nat_gateway
}

module "security_group" {
  count                 = length(var.sg_ids) == 0 ? 1 : 0
  source                = "./modules/security_group"
  prefix                = var.prefix
  vpc_id                = local.vpc_id
  allow_ssh_cidrs       = var.allow_ssh_cidrs
  alb_allow_https_cidrs = var.alb_allow_https_cidrs
  allow_weka_api_cidrs  = var.allow_weka_api_cidrs
  depends_on            = [module.network]
}

module "iam" {
  count                           = var.instance_iam_profile_arn == "" ? 1 : 0
  source                          = "./modules/iam"
  prefix                          = var.prefix
  cluster_name                    = var.cluster_name
  state_table_name                = local.dynamodb_table_name
  tiering_obs_name                = var.tiering_obs_name
  secret_prefix                   = local.secret_prefix
  tiering_enable_obs_integration  = var.tiering_enable_obs_integration
  additional_iam_policy_statement = var.additional_instance_iam_policy_statement
}

module "vpc_endpoint" {
  count                          = var.vpc_endpoint_ec2_create || var.vpc_endpoint_proxy_create || var.vpc_endpoint_s3_gateway_create ? 1 : 0
  source                         = "./modules/endpoint"
  region                         = data.aws_region.current.name
  create_vpc_endpoint_ec2        = var.vpc_endpoint_ec2_create
  create_vpc_endpoint_s3_gateway = var.vpc_endpoint_s3_gateway_create
  create_vpc_endpoint_proxy      = var.vpc_endpoint_proxy_create
  prefix                         = var.prefix
  vpc_id                         = local.vpc_id
  sg_ids                         = length(var.sg_ids) == 0 ? module.security_group[0].sg_ids : var.sg_ids
  subnet_ids                     = local.subnet_ids
  depends_on                     = [module.network, module.security_group]
}

locals {
  subnet_ids                    = length(var.subnet_ids) == 0 && length(module.network) > 0 ? module.network[0].subnet_ids : var.subnet_ids
  additional_subnet_id          = var.create_alb ? var.alb_additional_subnet_id == "" ? module.network[0].additional_subnet_id : var.alb_additional_subnet_id : ""
  vpc_id                        = length(var.subnet_ids) == 0 ? module.network[0].vpc_id : var.vpc_id
  sg_ids                        = length(var.sg_ids) == 0 && length(module.security_group) > 0 ? module.security_group[0].sg_ids : var.sg_ids
  alb_sg_ids                    = var.create_alb ? length(var.alb_sg_ids) > 0 ? var.alb_sg_ids : local.sg_ids : []
  instance_iam_profile_arn      = var.instance_iam_profile_arn == "" ? module.iam[0].instance_iam_profile_arn : var.instance_iam_profile_arn
  lambda_iam_role_arn           = var.lambda_iam_role_arn == "" ? module.iam[0].lambda_iam_role_arn : var.lambda_iam_role_arn
  sfn_iam_role_arn              = var.sfn_iam_role_arn == "" ? module.iam[0].sfn_iam_role_arn : var.sfn_iam_role_arn
  event_iam_role_arn            = var.event_iam_role_arn == "" ? module.iam[0].event_iam_role_arn : var.event_iam_role_arn
  secretmanager_endpoint_sg_ids = length(var.secretmanager_sg_ids) > 1 ? var.secretmanager_sg_ids : local.sg_ids
}

# endpoint to secret manager
resource "aws_vpc_endpoint" "secretmanager_endpoint" {
  count               = var.secretmanager_use_vpc_endpoint && var.secretmanager_create_vpc_endpoint ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = local.secretmanager_endpoint_sg_ids
  subnet_ids          = local.subnet_ids
  private_dns_enabled = true
  tags = {
    Name        = "${var.prefix}-secretmanager-endpoint"
    Environment = var.prefix
  }
  depends_on = [module.network]
}
