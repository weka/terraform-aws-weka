terraform {
  required_version = ">= 1.4.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.5.0"
    }
  }
}

provider "aws" {
  profile = "cloud-dev"
  region = "eu-west-1"
}

module "weka_deployment" {
  source             = "../../"
  prefix             = "denise-tf"
  cluster_name       = "poc"
  availability_zones = ["eu-west-1c"]
  allow_ssh_cidrs    = ["0.0.0.0/0"]
  get_weka_io_token  = var.get_weka_io_token
  vpc_endpoint_ec2_create = true
  proxy_url = "http://private.prod.weka.io:1080"
  subnet_autocreate_as_private = true
  vpc_endpoint_s3_gateway_create = true
  vpc_endpoint_proxy_create = true
  assign_public_ip = false
}
