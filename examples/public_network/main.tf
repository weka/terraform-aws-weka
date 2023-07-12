variable "get_weka_io_token" {
  type        = string
  description = "Weka IO token"
}

provider "aws" {
}

module "deploy-weka" {
  source             = "../../"
  prefix             = "weka-tf"
  cluster_name       = "test"
  availability_zones = ["a"]
  allow_ssh_ranges   = ["0.0.0.0/0"]
  get_weka_io_token  = var.get_weka_io_token
}

output "helpers_commands" {
  value = module.deploy-weka.cluster_helpers_commands
}
