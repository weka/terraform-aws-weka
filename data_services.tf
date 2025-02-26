module "data_services" {
  count                    = var.data_services_number > 0 ? 1 : 0
  source                   = "./modules/data_services"
  subnet_id                = var.data_services_subnet_id != null ? var.data_services_subnet_id : local.subnet_ids[0]
  data_services_number     = var.data_services_number
  data_services_name       = "${local.ec2_prefix}-${var.cluster_name}-data-services"
  iam_base_name            = "${local.iam_prefix}-${var.cluster_name}-data-services"
  cluster_name             = var.cluster_name
  instance_type            = var.data_services_instance_type
  key_pair_name            = var.enable_key_pair ? var.key_pair_name == null ? aws_key_pair.generated_key[0].key_name : var.key_pair_name : null
  assign_public_ip         = var.assign_public_ip
  placement_group_name     = local.backends_placement_group_name
  use_placement_group      = var.use_placement_group
  weka_volume_size         = var.data_services_weka_volume_size
  ami_id                   = var.data_services_instance_ami_id
  sg_ids                   = local.sg_ids
  tags_map                 = var.tags_map
  instance_iam_profile_arn = var.data_services_instance_iam_profile_arn
  install_weka_url         = local.install_weka_url
  proxy_url                = var.proxy_url
  secret_prefix            = local.secret_prefix
  ebs_encrypted            = var.ebs_encrypted
  ebs_kms_key_id           = local.kms_key_id
  deploy_lambda_name       = aws_lambda_function.deploy_lambda.function_name
  report_lambda_name       = aws_lambda_function.report_lambda.function_name
  fetch_lambda_name        = aws_lambda_function.fetch_lambda.function_name
  status_lambda_name       = aws_lambda_function.status_lambda.function_name
  metadata_http_tokens     = var.metadata_http_tokens
  capacity_reservation_id  = var.data_services_capacity_reservation_id
  root_volume_size         = var.data_services_root_volume_size
  depends_on               = [aws_autoscaling_group.autoscaling_group, aws_lb.alb, module.network]
}
