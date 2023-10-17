



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
  profile = "selfservice"
  region = "eu-west-2"
}

module "weka_deployment" {
  source                     = "../../"
  prefix                     = "weka"
  vpc_id                     = "vpc-0a9c7a10da0d5d68f"
  subnet_ids                 = ["subnet-0630c41fa9aa5706f"]
  sg_ids                     = ["sg-09d03fe0d9395594c"]
  cluster_name               = "poc"
  availability_zones         = ["b"]
  get_weka_io_token          = "M0XtZR2QiNlhpzc4"
  create_alb                 = false
  private_network            = true
  sfn_iam_role_arn           = "arn:aws:iam::023156170196:role/weka-selfservice-sfn-role"
  lambda_iam_role_arn        = "arn:aws:iam::023156170196:role/weka-selfservice-lambda-role"
  event_iam_role_arn         = "arn:aws:iam::023156170196:role/weka-selfservice-event-role"
  instance_iam_profile_arn   = "arn:aws:iam::023156170196:instance-profile/weka-selfservice-instance-profile"
  lambdas_dist               = "dev"
  assign_public_ip           = false
  create_ec2_endpoint        = true
  create_s3_gateway_endpoint = true
  create_proxy_endpoint      = true
  proxy_url                  = "http://private.prod.weka.io:1080"


}

output "outputs" {
  value = module.weka_deployment
}
