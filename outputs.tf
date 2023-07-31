locals {
  ips_type = var.private_network ? "PrivateIpAddress" : "PublicIpAddress"
}

output "ssh_user" {
  value = var.vm_username
}

output "local_ssh_private_key" {
  value = var.ssh_public_key == null && var.key_pair_name == null ? "${local.ssh_path}-private-key.pem" : null
}

output "cluster_name" {
  value = var.cluster_name
}

output "ips_type" {
  value = local.ips_type
}

output "lambda_name" {
  value = aws_lambda_function.status_lambda.function_name
}

output "weka_cluster_password_secret_id" {
  value = aws_secretsmanager_secret.weka_password.id
}

output "alb_dns_name" {
  value = var.create_alb ? aws_lb.alb[0].dns_name : null
}

output "alb_alias_record" {
  value = var.alb_alias_name != "" ? aws_route53_record.lb_record[0].fqdn : null
}

output "helper_commands" {
  value = <<EOT
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[]| select( .Tags[].Value == "${var.cluster_name}").Instances[].InstanceId') | jq -r '.Reservations[].Instances[].${local.ips_type}'
aws lambda invoke --function-name ${aws_lambda_function.status_lambda.function_name} --payload '{"type": "progress"}' --cli-binary-format raw-in-base64-out /dev/stdout
aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.weka_password.id} --query SecretString --output text
EOT
}

output "client-ips" {
  value = var.clients_number == 0 ? null : <<EOT
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(Tags[?Value=='${module.clients[0].clients_name}'].Value, '${module.clients[0].clients_name}')].Instances[].InstanceId" --output text) | jq -r '.Reservations[].Instances[].${local.ips_type}'
EOT
}
