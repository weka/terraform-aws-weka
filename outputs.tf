locals {
  ips_type                          = local.assign_public_ip ? "PublicIpAddress" : "PrivateIpAddress"
  asg_name                          = aws_autoscaling_group.autoscaling_group.name
  weka_admin_password_secret_id     = aws_secretsmanager_secret.weka_password.id
  cert_pem_secret_id                = local.create_self_signed_certificate ? aws_secretsmanager_secret.self_signed_certificate_private_key[0].id : ""
  smb_pre_terraform_destroy_command = var.smb_protocol_gateways_number == 0 ? "" : <<EOT
 echo ${join(" ", module.smb_protocol_gateways[0].instance_ids)} | xargs -n 1 aws ec2 modify-instance-attribute --region ${local.region} --no-disable-api-stop --instance-id
EOT
  s3_pre_terraform_destroy_command  = var.s3_protocol_gateways_number == 0 ? "" : <<EOT
 echo ${join(" ", module.s3_protocol_gateways[0].instance_ids)} | xargs -n 1 aws ec2 modify-instance-attribute --region ${local.region} --no-disable-api-stop --instance-id
EOT
  get_cert_private_key              = <<EOT
aws secretsmanager get-secret-value \
  --secret-id ${local.cert_pem_secret_id} \
  --region ${local.region} \
  --query SecretString \
  --output text
EOT
}

output "local_ssh_private_key" {
  value       = var.enable_key_pair ? var.ssh_public_key == null && var.key_pair_name == null ? "${local.ssh_path}-private-key.pem" : null : null
  description = "If 'ssh_public_key' is set to null and no key_pair_name provided, it will output the private ssh key location."
}

output "cluster_name" {
  value       = var.cluster_name
  description = "The cluster name"
}

output "ips_type" {
  value       = local.ips_type
  description = "If 'assign_public_ip' is set to true, it will output the public ips, If no it will output the private ips"
}

output "lambda_status_name" {
  value       = aws_lambda_function.status_lambda.function_name
  description = "Name of lambda status"
}

output "weka_cluster_admin_password_secret_id" {
  value       = local.weka_admin_password_secret_id
  description = "Secret id of weka admin password"
}

output "alb_dns_name" {
  value       = local.alb_dns_name
  description = "If 'create_alb` set to true, it will output dns name of the ALB"
}

output "asg_name" {
  value       = aws_autoscaling_group.autoscaling_group.name
  description = "Name of ASG"
}

output "placement_group_name" {
  value       = local.backends_placement_group_name
  description = "Name of placement group"
}

output "vpc_id" {
  value       = local.vpc_id
  description = "VPC id"
}

output "subnet_ids" {
  value       = local.subnet_ids
  description = "Subnet ids of backends"
}

output "sg_ids" {
  value       = local.sg_ids
  description = "Security group ids of backends"
}

output "cluster_helper_commands" {
  value = {
    "get_ips"      = <<EOT
aws ec2 describe-instances \
  --instance-ids $(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-name ${local.asg_name} \
      --region ${local.region} \
      --query "AutoScalingGroups[].Instances[].InstanceId" --output text) \
  --region ${local.region} \
  --query 'Reservations[].Instances[].${local.ips_type}' \
  --output json
EOT
    "get_password" = <<EOT
aws secretsmanager get-secret-value \
  --secret-id ${local.weka_admin_password_secret_id} \
  --region ${local.region} \
  --query SecretString \
  --output text
EOT
    "get_status"   = <<EOT
# for nfs use: --payload '{"type": "progress", "protocol": "nfs"}'
aws lambda invoke \
  --function-name ${aws_lambda_function.status_lambda.function_name} \
  --payload '{"type": "progress"}' \
  --region ${local.region} \
  --cli-binary-format raw-in-base64-out /dev/stdout
EOT
  }
}

output "client_helper_commands" {
  value = var.clients_number == 0 ? null : module.clients[0].client_helper_commands
}

output "client_asg_name" {
  value = var.clients_number == 0 ? null : var.clients_use_autoscaling_group ? module.clients[0].asg_name : null
}

output "client_ips" {
  value       = var.clients_number == 0 ? null : module.clients[0].client_ips
  description = "Ips of clients"
}

output "smb_protocol_gateways_ips" {
  value       = var.smb_protocol_gateways_number == 0 ? null : <<EOT
 echo $(aws ec2 describe-instances --region ${local.region} --filters "Name=tag:Name,Values=${module.smb_protocol_gateways[0].gateways_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of SMB protocol gateways"
}

output "smb_protocol_gateways_name" {
  value       = var.smb_protocol_gateways_number == 0 ? null : module.smb_protocol_gateways[0].gateways_name
  description = "Name of SMB protocol gateway instances"
}

output "s3_protocol_gateways_ips" {
  value       = var.s3_protocol_gateways_number == 0 ? null : <<EOT
 echo $(aws ec2 describe-instances --region ${local.region} --filters "Name=tag:Name,Values=${module.s3_protocol_gateways[0].gateways_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of S3 protocol gateways"
}

output "s3_protocol_gateways_name" {
  value       = var.s3_protocol_gateways_number == 0 ? null : module.s3_protocol_gateways[0].gateways_name
  description = "Name of S3 protocol gateway instances"
}

output "nfs_protocol_gateways_ips" {
  value       = var.nfs_protocol_gateways_number == 0 ? null : <<EOT
 echo $(aws ec2 describe-instances --region ${local.region} --filters "Name=tag:Name,Values=${module.nfs_protocol_gateways[0].gateways_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of NFS protocol gateways"
}

output "nfs_protocol_gateways_name" {
  value       = var.nfs_protocol_gateways_number == 0 ? null : module.nfs_protocol_gateways[0].gateways_name
  description = "Name of NFS protocol gateway instances"
}

output "data_services_ips" {
  value       = var.data_services_number == 0 ? null : <<EOT
 echo $(aws ec2 describe-instances --region ${local.region} --filters "Name=tag:Name,Values=${module.data_services[0].data_services_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of the data services instances"
}

output "deploy_lambda_name" {
  value = aws_lambda_function.deploy_lambda.function_name
}

output "pre_terraform_destroy_command" {
  value       = var.smb_protocol_gateways_number == 0 && var.s3_protocol_gateways_number == 0 ? "" : "${local.smb_pre_terraform_destroy_command}${local.s3_pre_terraform_destroy_command}"
  description = "Mandatory pre-destroy steps only when S3/SMB protocol gateways are crated. Terraform doesn't handle protection removal."
}

output "get_cert_private_key" {
  value       = local.create_self_signed_certificate ? local.get_cert_private_key : null
  description = "Command to get the self-signed certificate private key"
}
