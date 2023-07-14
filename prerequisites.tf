data aws_region current {}

locals {
  region = data.aws_region.current.name
}

module "network" {
  count              = length(var.subnet_ids) == 0 ? 1 : 0
  source             = "./modules/network"
  prefix             = var.prefix
  availability_zones = var.availability_zones
}

module "security_group" {
  count  = length(var.sg_id) == 0 ? 1 : 0
  source = "./modules/security-group"
  prefix = var.prefix
  vpc_id = local.vpc_id
  allow_ssh_ranges = var.allow_ssh_ranges
  depends_on = [module.network]
}

module "iam" {
  count  = var.instance_iam_profile_arn == "" ? 1 : 0
  source = "./modules/iam"
  prefix = var.prefix
  cluster_name = var.cluster_name
  state_table_name = local.dynamodb_table_name
  obs_name = var.obs_name
  secret_prefix = local.secret_prefix
}

locals {
  subnet_ids = length(var.subnet_ids) == 0 ? module.network[0].subnet_ids : var.subnet_ids
  vpc_id = length(var.subnet_ids) == 0 ? module.network[0].vpc_id : var.vpc_id
  sg_id = length(var.sg_id) == 0 ? [module.security_group[0].sg_id] : var.sg_id
  instance_iam_profile_arn = var.instance_iam_profile_arn == "" ? module.iam[0].instance_iam_profile_arn : var.instance_iam_profile_arn
  lambda_iam_role_arn = var.lambda_iam_role_arn == "" ? module.iam[0].lambda_iam_role_arn : var.lambda_iam_role_arn
}
