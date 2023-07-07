provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

module "create-network" {
  source             = "../../modules/create-network"
  vpc_cidr           = var.vpc_cidr
  region             = var.region
  prefix             = var.prefix
  availability_zones = var.availability_zones
  subnets_cidr       = var.subnets_cidr
  aws_profile        = var.aws_profile
  allow_ssh_from_ips = var.allow_ssh_from_ips
}

module "deploy-weka" {
  source             = "../../"
  subnets            = module.create-network.subnets
  availability_zones = var.availability_zones
  region             = var.region
  get_weka_io_token  = var.get_weka_io_token
  sg_id              = module.create-network.sg-id
  aws_profile        = var.aws_profile
  cluster_name       = var.cluster_name
  cluster_size       = var.cluster_size
  instance_type      = var.instance_type
  prefix             = var.prefix
  depends_on         = [module.create-network]
}
