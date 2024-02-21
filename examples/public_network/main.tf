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
}

module "weka_deployment" {
  source             = "../../"
  prefix             = "weka-tf"
  cluster_name       = "poc"
  availability_zones = ["eu-west-1c"]
  allow_ssh_cidrs    = ["0.0.0.0/0"]
  assign_public_ip   = true
  get_weka_io_token  = var.get_weka_io_token
}
