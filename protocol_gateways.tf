module "smb_protocol_gateways" {
  count                        = var.smb_protocol_gateways_number > 0 ? 1 : 0
  source                       = "./modules/protocol_gateways"
  subnet_id                    = local.subnet_ids[0]
  setup_protocol               = var.smb_setup_protocol
  gateways_number              = var.smb_protocol_gateways_number
  gateways_name                = "${var.prefix}-${var.cluster_name}-smb-protocol-gateway"
  protocol                     = "SMB"
  frontend_container_cores_num = var.smb_protocol_gateway_fe_cores_num
  secondary_ips_per_nic        = var.smb_protocol_gateway_secondary_ips_per_nic
  lb_arn_suffix                = var.create_alb ? aws_lb.alb[0].arn_suffix : ""
  backends_asg_name            = aws_autoscaling_group.autoscaling_group.name
  instance_type                = var.smb_protocol_gateway_instance_type
  key_pair_name                = var.key_pair_name != null ? var.key_pair_name : aws_key_pair.generated_key[0].key_name
  assign_public_ip             = var.assign_public_ip
  placement_group_name         = local.backends_placement_group_name
  weka_volume_size             = var.smb_protocol_gateway_weka_volume_size
  ami_id                       = var.ami_id
  sg_ids                       = local.sg_ids
  tags_map                     = var.tags_map
  instance_iam_profile_arn     = var.smb_protocol_gateway_instance_iam_profile_arn
  install_weka_url             = local.install_weka_url
  weka_token_id                = aws_secretsmanager_secret.get_weka_io_token.id
  weka_password_id             = aws_secretsmanager_secret.weka_password.id
  proxy_url                    = var.proxy_url
  secret_prefix                = local.secret_prefix
  smb_cluster_name             = var.smb_cluster_name
  smb_domain_name              = var.smb_domain_name
  smbw_enabled                 = var.smbw_enabled
  depends_on                   = [aws_autoscaling_group.autoscaling_group, aws_lb.alb, module.network]
}


module "nfs_protocol_gateways" {
  count                        = var.nfs_protocol_gateways_number > 0 ? 1 : 0
  source                       = "./modules/protocol_gateways"
  subnet_id                    = local.subnet_ids[0]
  setup_protocol               = var.nfs_setup_protocol
  gateways_number              = var.nfs_protocol_gateways_number
  gateways_name                = "${var.prefix}-${var.cluster_name}-nfs-protocol-gateway"
  protocol                     = "NFS"
  frontend_container_cores_num = var.nfs_protocol_gateway_fe_cores_num
  secondary_ips_per_nic        = var.nfs_protocol_gateway_secondary_ips_per_nic
  lb_arn_suffix                = var.create_alb ? aws_lb.alb[0].arn_suffix : ""
  backends_asg_name            = aws_autoscaling_group.autoscaling_group.name
  instance_type                = var.nfs_protocol_gateway_instance_type
  key_pair_name                = var.key_pair_name != null ? var.key_pair_name : aws_key_pair.generated_key[0].key_name
  assign_public_ip             = var.assign_public_ip
  placement_group_name         = local.backends_placement_group_name
  weka_volume_size             = var.nfs_protocol_gateway_weka_volume_size
  ami_id                       = var.ami_id
  sg_ids                       = local.sg_ids
  tags_map                     = var.tags_map
  instance_iam_profile_arn     = var.nfs_protocol_gateway_instance_iam_profile_arn
  install_weka_url             = local.install_weka_url
  weka_token_id                = aws_secretsmanager_secret.get_weka_io_token.id
  weka_password_id             = aws_secretsmanager_secret.weka_password.id
  proxy_url                    = var.proxy_url
  secret_prefix                = local.secret_prefix
  depends_on                   = [aws_autoscaling_group.autoscaling_group, aws_lb.alb, module.network]
}
