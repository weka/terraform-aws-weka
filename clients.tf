module "clients" {
  count                    = var.clients_number > 0 ? 1 : 0
  source                   = "./modules/clients"
  availability_zone        = var.availability_zones[0]
  subnet_id                = local.subnet_ids[0]
  clients_name             = "${var.prefix}-${var.cluster_name}-client"
  clients_number           = var.clients_number
  mount_clients_dpdk       = var.mount_clients_dpdk
  proxy_url                = var.proxy_url
  nics_numbers             = var.mount_clients_dpdk ? var.client_nics_num : 1
  instance_type            = var.client_instance_type
  backends_asg_name        = aws_autoscaling_group.autoscaling_group.name
  weka_cluster_size        = var.cluster_size
  alb_dns_name             = var.create_alb ? aws_lb.alb[0].dns_name : null
  key_pair_name            = var.key_pair_name != null ? var.key_pair_name : aws_key_pair.generated_key[0].key_name
  assign_public_ip         = var.assign_public_ip
  placement_group_name     = var.client_placement_group_name
  root_volume_size         = var.client_root_volume_size
  ami_id                   = var.client_instance_ami_id
  sg_ids                   = local.sg_ids
  tags_map                 = var.tags_map
  instance_iam_profile_arn = var.client_instance_iam_profile_arn
  depends_on               = [aws_autoscaling_group.autoscaling_group, module.network]
}
