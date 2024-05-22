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
  source              = "../../"
  prefix              = "denise3"
  cluster_name        = "al3"
  availability_zones  = ["eu-west-1c"]
  allow_ssh_cidrs     = ["0.0.0.0/0"]
  get_weka_io_token   = var.get_weka_io_token
  clients_number      = 2
  #nfs_protocol_gateways_number = 4
  #nfs_setup_protocol = true
  assign_public_ip    = true
  weka_version        = "4.2.11"
}
