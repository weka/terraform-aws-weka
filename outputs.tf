locals {
  path_ssh_keys = var.ssh_public_key == null ? "${local.ssh_path}-public-key.pub\n${local.ssh_path}-private-key.pem" : ""
  ips           = var.private_network ? "PrivateIpAddress" : "PublicIpAddress"
}


output "cluster_helpers_commands" {
  value = <<EOT
############################################## path to ssh keys  ##########################################################################
${local.path_ssh_keys}
user: ${var.vm_username}

############################################## ec2 public ips #############################################################################
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[]| select( .Tags[].Value == "${var.cluster_name}").Instances[].InstanceId') | jq -r '.Reservations[].Instances[].${local.ips}'

##############################################   status url   #############################################################################
aws lambda invoke --function-name ${aws_lambda_function.status_lambda.function_name} --payload '{"type": "progress"}' --cli-binary-format raw-in-base64-out /dev/stdout

##############################################      state     #############################################################################
aws dynamodb get-item --table-name ${local.dynamodb_table_name} --key '{"${local.dynamodb_hash_key_name}": {"S": "${local.state_key}"}}' | jq -r '.Item.Value.M'

############################################## cluster password ###########################################################################
aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.weka_password.id} --query SecretString --output text
EOT
}
