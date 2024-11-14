module "base_infrastructure" {
  source      = "../../modules/base"
  name_prefix = "setup"
}

module "scenario_infrastructure" {
  source = "../../modules/setup-weka"

  subnet_id         = module.base_infrastructure.subnet_id
  private_subnet_id = module.base_infrastructure.private_subnet_id
  security_group_id = module.base_infrastructure.security_group_id
  key_name          = module.base_infrastructure.keypair_name
  random_pet_id     = module.base_infrastructure.random_pet_id
}
