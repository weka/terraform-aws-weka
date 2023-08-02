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

module "deploy_weka" {
  source             = "../../"
  prefix             = "weka-tf"
  cluster_name       = "test"
  availability_zones = ["a"]
  allow_ssh_ranges   = ["0.0.0.0/0"]
  get_weka_io_token  = var.get_weka_io_token
}
