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
  region = "eu-west-1"
}

module "weka_deployment" {
  source = "../../"
  prefix = "denise4"
  cluster_name        = "alb4"
  availability_zones  = ["eu-west-1c"]
  allow_ssh_cidrs     = ["0.0.0.0/0"]
  get_weka_io_token   = var.get_weka_io_token
  clients_number      = 2
  create_alb = false
 # alb_acm_domain_name = "weka.io"
  assign_public_ip    = true
  #alb_alias_name = "alb.weka.io"
  #alb_route53_zone_id = "Z30278605XVWXB"
 # alb_cert_arn = "arn:aws:acm:eu-west-1:389791687681:certificate/ea768f03-fd5a-4ff3-8c92-970033fb6fde"
  install_weka_url = "https://$TOKEN@get.prod.weka.io/dist/v1/install/4.3.1-91c32d62f7bf238e/4.3.1.29741-ab4c2993a60f5af7bdb3e15fa4266c6e"
}
