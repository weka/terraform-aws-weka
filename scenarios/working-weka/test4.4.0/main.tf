module "base_infrastructure" {
  source      = "../../../modules/base"
  name_prefix = "working-weka"
}

module "scenario_infrastructure" {
  source = "../../../modules/weka-installed"
  name_prefix = "working-weka"
  weka_version = "4.4.0"
  
  subnet_id         = module.base_infrastructure.subnet_id
  private_subnet_id = module.base_infrastructure.private_subnet_id
  security_group_id = module.base_infrastructure.security_group_id
  key_name          = module.base_infrastructure.keypair_name
  random_pet_id     = module.base_infrastructure.random_pet_id
  private_key_pem = module.base_infrastructure.private_key_pem
  other_private_ips = module.base_infrastructure.instance_private_ips
  other_public_ips  = module.base_infrastructure.instance_public_ips
  

}
