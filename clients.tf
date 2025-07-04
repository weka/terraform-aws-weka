module "clients" {
  # in case the clients number is 0 and the instance_iam_profile_arn is empty, we will run the module just to create the IAM role
  count                        = var.clients_number > 0 || var.instance_iam_profile_arn == "" ? 1 : 0
  source                       = "./modules/clients"
  subnet_id                    = local.subnet_ids[0]
  clients_name                 = "${local.ec2_prefix}-${var.cluster_name}-client"
  iam_base_name                = "${local.iam_prefix}-${var.cluster_name}-client"
  clients_number               = var.clients_number
  clients_use_dpdk             = var.clients_use_dpdk
  proxy_url                    = var.proxy_url
  frontend_container_cores_num = var.clients_use_dpdk ? var.client_frontend_cores : 1
  instance_type                = var.client_instance_type
  backends_asg_name            = aws_autoscaling_group.autoscaling_group.name
  alb_dns_name                 = local.alb_dns_name
  key_pair_name                = var.enable_key_pair ? var.key_pair_name == null ? aws_key_pair.generated_key[0].key_name : var.key_pair_name : null
  assign_public_ip             = local.assign_public_ip
  placement_group_name         = var.client_placement_group_name != null || !var.client_use_backends_placement_group ? var.client_placement_group_name : local.backends_placement_group_name
  use_placement_group          = var.use_placement_group
  client_instance_ami_id       = var.client_instance_ami_id
  sg_ids                       = local.sg_ids
  tags_map                     = var.tags_map
  ebs_encrypted                = var.ebs_encrypted
  ebs_kms_key_id               = local.ebs_kms_key_id
  instance_iam_profile_arn     = var.client_instance_iam_profile_arn
  use_autoscaling_group        = var.clients_use_autoscaling_group
  custom_data                  = var.clients_custom_data
  custom_data_pre_mount        = var.clients_custom_data_pre_mount
  custom_data_post_mount       = var.clients_custom_data_post_mount
  arch                         = var.client_arch
  capacity_reservation_id      = var.client_capacity_reservation_id
  metadata_http_tokens         = var.metadata_http_tokens
  root_volume_size             = var.clients_root_volume_size
  cert_pem                     = local.create_self_signed_certificate ? module.self_signed_certificate[0].cert_pem : null
  depends_on                   = [aws_autoscaling_group.autoscaling_group, module.network]
}
