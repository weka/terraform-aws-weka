locals {
  ips_type = var.assign_public_ip ? "PublicIpAddress" : "PrivateIpAddress"
  asg_name = aws_autoscaling_group.autoscaling_group.name
}

output "vm_username" {
  value       = var.vm_username
  description = "Provided as part of output for automated use of terraform, in case of custom AMI and automated use of outputs replace this with user that should be used for ssh connection"
}

output "local_ssh_private_key" {
  value       = var.ssh_public_key == null && var.key_pair_name == null ? "${local.ssh_path}-private-key.pem" : null
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
  value       = var.placement_group_name != null ? var.placement_group_name : aws_placement_group.placement_group[0].name
  description = "Name of placement group"
}

output "cluster_helper_commands" {
  value = <<EOT
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${local.asg_name} --query "AutoScalingGroups[].Instances[].InstanceId" --output text) --query 'Reservations[].Instances[].${local.ips_type}' --output json
aws lambda invoke --function-name ${aws_lambda_function.status_lambda.function_name} --payload '{"type": "progress"}' --cli-binary-format raw-in-base64-out /dev/stdout
aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.weka_password.id} --query SecretString --output text
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
 echo $(aws ec2 describe-instances --filters "Name=tag:Name,Values=${module.smb_protocol_gateways[0].gateways_name}" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of SMB protocol gateways"
}

output "nfs_protocol_gateways_ips" {
  value       = var.nfs_protocol_gateways_number == 0 ? null : <<EOT
 echo $(aws ec2 describe-instances --filters "Name=tag:Name,Values=${module.nfs_protocol_gateways[0].gateways_name}" --query 'Reservations[*].Instances[*].{Instance:InstanceId,PrivateIpAddress:PrivateIpAddress,PublicIpAddress:PublicIpAddress}')
EOT
  description = "Ips of NFS protocol gateways"
}
