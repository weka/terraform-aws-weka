locals {
  path_ssh_keys = var.ssh_public_key == null ? "${local.ssh_path}-public-key.pub\n${local.ssh_path}-private-key.pem" : ""
}


output "cluster_helpers_commands" {
  value = <<EOT
############################################## path to ssh keys  ##########################################################################
${local.path_ssh_keys}
user: ${var.vm_username}

############################################## ec2 public ips #############################################################################
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[]| select( .Tags[].Value == "${var.cluster_name}").Instances[].InstanceId') | jq -r '.Reservations[].Instances[].PublicIpAddress'

############################################## status url     #############################################################################
curl ${aws_lambda_function_url.status_lambda_url.function_url} -H "Content-Type:application/json" -d '{"type":"progress"}'

############################################## cluster password ###########################################################################
aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.weka_password.id} --query SecretString --output text
EOT
}
