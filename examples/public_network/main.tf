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
  profile = "dev"
}

module "weka_deployment" {
  source                         = "../../"
  prefix                         = "denise"
  cluster_name                   = "smb"
  availability_zones             = ["eu-west-1a"]
  allow_ssh_cidrs                = ["0.0.0.0/0"]
  get_weka_io_token              = var.get_weka_io_token
  clients_number                 = 1
  weka_version                   = "4.2.18.14"
  instance_type                  = "i3en.6xlarge"
  cluster_size                   = 6
  ssh_public_key                 = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC83xywjfh32vOUZGc2cWMBI7s0krK1au2EkWSTLkkOnsW7QVulrwqT5yi+02lVsJ7TPIV0DYTyg2GjkcUoBOyTu0/Msly9cTPv033SD+17CY3WAG29kY0OGkxSugpEWp4Z+vaQqGWP0G3D7yxBXQ0m0W3yDzNV+Jk3PERh4t7VU4T+zRmGy1cBttW1nQH9BewqgNfynQvUr3/YBkQXP0g2yTWtFM+0BUv4imcNpgm4/MQyQX41PJt0ey8v/pEuz9Hl75aZINwkdbQvSVWO2pcwwtkMtSK/89kYKCI3bF0gBSUPlnoPZorYyk+Y99nrOLUhSdrC8IjZ2DLQfzuwLNtl weka_id_rsa_2019.05.27"
  assign_public_ip               = "true"
  smb_cluster_name = "smbdenise2"
  smb_domain_name = "ad.wekaio.lab"
  smb_protocol_gateways_number = 3
  smb_setup_protocol = true
  smbw_enabled = true
  data_services_number = 1


}
