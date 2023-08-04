data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

module "network" {
  count              = length(var.subnet_ids) == 0 ? 1 : 0
  source             = "./modules/network"
  prefix             = var.prefix
  availability_zones = var.availability_zones
  private_network    = var.private_network
  additional_subnet  = var.create_alb
}

module "security_group" {
  count            = length(var.sg_ids) == 0 ? 1 : 0
  source           = "./modules/security-group"
  prefix           = var.prefix
  vpc_id           = local.vpc_id
  allow_ssh_ranges = var.allow_ssh_ranges
  depends_on       = [module.network]
}

module "iam" {
  count               = var.instance_iam_profile_arn == "" ? 1 : 0
  source              = "./modules/iam"
  prefix              = var.prefix
  cluster_name        = var.cluster_name
  state_table_name    = local.dynamodb_table_name
  obs_name            = var.obs_name
  secret_prefix       = local.secret_prefix
  set_obs_integration = var.set_obs_integration
}

locals {
  subnet_ids                    = length(var.subnet_ids) == 0 ? module.network[0].subnet_ids : var.subnet_ids
  additional_subnet_id          = var.create_alb ? var.additional_alb_subnet == "" ? module.network[0].additional_subnet_id : var.additional_alb_subnet : ""
  vpc_id                        = length(var.subnet_ids) == 0 ? module.network[0].vpc_id : var.vpc_id
  sg_ids                        = length(var.sg_ids) == 0 ? module.security_group[0].sg_ids : var.sg_ids
  instance_iam_profile_arn      = var.instance_iam_profile_arn == "" ? module.iam[0].instance_iam_profile_arn : var.instance_iam_profile_arn
  lambda_iam_role_arn           = var.lambda_iam_role_arn == "" ? module.iam[0].lambda_iam_role_arn : var.lambda_iam_role_arn
  sfn_iam_role_arn              = var.sfn_iam_role == "" ? module.iam[0].sfn_iam_role_arn : var.sfn_iam_role
  event_iam_role_arn            = var.event_iam_role == "" ? module.iam[0].event_iam_role_arn : var.event_iam_role
  secretmanager_endpoint_sg_ids = length(var.secretmanager_endpoint_sg_ids) > 1 ? var.secretmanager_endpoint_sg_ids : local.sg_ids
}

# endpoint to secret manager
resource "aws_vpc_endpoint" "secretmanager_endpoint" {
  count               = var.use_secretmanager_endpoint && var.create_secretmanager_endpoint ? 1 : 0
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
