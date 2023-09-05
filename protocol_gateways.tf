data "aws_network_interface" "lb" {
  count = var.create_alb && var.protocol_gateways_number > 0 ? 1 : 0
  filter {
    name   = "description"
    values = ["ELB ${aws_lb.alb[0].arn_suffix}"]
  }
  filter {
    name   = "subnet-id"
    values = [local.subnet_ids[0]]
  }
  depends_on = [aws_lb.alb, aws_autoscaling_group.autoscaling_group, aws_lambda_function.deploy_lambda, aws_autoscaling_attachment.alb_autoscaling_attachment]
}

module "protocol_gateways" {
  count                    = var.protocol_gateways_number > 0 ? 1 : 0
  source                   = "./modules/protocol_gateways"
  availability_zone        = var.availability_zones[0]
  subnet_id                = local.subnet_ids[0]
  gateways_number          = var.protocol_gateways_number
  gateways_name            = "${var.prefix}-${var.cluster_name}-protocol-gateway"
  protocol                 = var.protocol
  nics_numbers             = var.protocol_gateway_nics_num
  secondary_ips_per_nic    = var.protocol_gateway_secondary_ips_per_nic
  backend_lb_ip            = var.create_alb ? data.aws_network_interface.lb[0].private_ip : null
  cluster_name             = var.cluster_name
  instance_type            = var.protocol_gateway_instance_type
  weka_cluster_size        = var.cluster_size
  key_pair_name            = var.key_pair_name != null ? var.key_pair_name : aws_key_pair.generated_key[0].key_name
  assign_public_ip         = var.assign_public_ip
  placement_group_name     = var.placement_group_name
  disk_size                = var.protocol_gateway_disk_size
  ami_id                   = var.ami_id
  sg_ids                   = local.sg_ids
  tags_map                 = var.tags_map
  instance_iam_profile_arn = var.protocol_gateway_instance_iam_profile_arn
  frontend_num             = var.protocol_gateway_frontend_num
  install_weka_url         = var.install_weka_url != "" ? var.install_weka_url : "https://$TOKEN@get.weka.io/dist/v1/install/${var.weka_version}/${var.weka_version}"
  weka_token_id            = aws_secretsmanager_secret.get_weka_io_token.id
  vm_username              = var.weka_username
  weka_password_id         = aws_secretsmanager_secret.weka_password.id
  proxy_url                = var.proxy_url
  secret_prefix            = "weka/${var.prefix}-${var.cluster_name}/"
  depends_on               = [aws_autoscaling_group.autoscaling_group, aws_lb.alb]
}