locals {
  ips_type = local.assign_public_ip ? "PublicIpAddress" : "PrivateIpAddress"
  asg_name = aws_autoscaling_group.autoscaling_group.name
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

output "weka_cluster_password_secret_id" {
  value       = aws_secretsmanager_secret.weka_password.id
  description = "Secret id of weka_password"
}

output "alb_dns_name" {
  value       = var.create_alb ? aws_lb.alb[0].dns_name : null
  description = "If 'create_alb` set to true, it will output dns name of the ALB"
}

output "alb_alias_record" {
  value       = var.alb_alias_name != "" ? aws_route53_record.lb_record[0].fqdn : null
  description = "If 'alb_alias_name` not null, it will output fqdn of the ALB"
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
  value = <<EOT
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${local.asg_name} --region ${local.region} --query "AutoScalingGroups[].Instances[].InstanceId" --output text) --region ${local.region} --query 'Reservations[].Instances[].${local.ips_type}' --output json
# for nfs use: --payload '{"type": "progress", "protocl": "nfs"}'
aws lambda invoke --function-name ${aws_lambda_function.status_lambda.function_name} --payload '{"type": "progress"}' --region ${local.region} --cli-binary-format raw-in-base64-out /dev/stdout
aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.weka_password.id} --region ${local.region} --query SecretString --output text
EOT
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
 echo $(aws ec2 describe-instances --filters "Name=tag:Name,Values=${module.smb_protocol_gateways[0].gateways_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of SMB protocol gateways"
}

output "nfs_protocol_gateways_ips" {
  value       = var.nfs_protocol_gateways_number == 0 ? null : <<EOT
 echo $(aws ec2 describe-instances --filters "Name=tag:Name,Values=${module.nfs_protocol_gateways[0].gateways_name}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of NFS protocol gateways"
}

output "deploy_lambda_name" {
  value = aws_lambda_function.deploy_lambda.function_name
}
