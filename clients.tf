module "clients" {
  count                    = var.clients_number > 0 ? 1 : 0
  source                   = "./modules/clients"
  subnet_id                = local.subnet_ids[0]
  clients_name             = "${var.prefix}-${var.cluster_name}-client"
  clients_number           = var.clients_number
  clients_use_dpdk         = var.clients_use_dpdk
  proxy_url                = var.proxy_url
  client_frontend_cores    = var.clients_use_dpdk ? var.client_frontend_cores : 1
  instance_type            = var.client_instance_type
  backends_asg_name        = aws_autoscaling_group.autoscaling_group.name
  weka_cluster_size        = var.cluster_size
  alb_dns_name             = var.create_alb ? aws_lb.alb[0].dns_name : null
  key_pair_name            = var.key_pair_name != null ? var.key_pair_name : aws_key_pair.generated_key[0].key_name
  assign_public_ip         = var.assign_public_ip
  placement_group_name     = var.client_placement_group_name
  weka_volume_size         = var.client_weka_volume_size
  client_instance_ami_id   = var.client_instance_ami_id
  sg_ids                   = local.sg_ids
  tags_map                 = var.tags_map
  instance_iam_profile_arn = var.client_instance_iam_profile_arn
  depends_on               = [aws_autoscaling_group.autoscaling_group, module.network]
}
