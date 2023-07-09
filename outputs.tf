locals {
  aws_profile   = var.aws_profile  != null ? "AWS_PROFILE=${var.aws_profile}" : ""
  path_ssh_keys = var.ssh_private_key_path == null ? "${local.ssh_path}-public-key.pub\n${local.ssh_path}-private-key.pem" : "${var.ssh_private_key_path} \n ${var.ssh_public_key_path}"
}


output "cluster_helpers_commands" {
  value = <<EOT
############################################## Path to ssh keys  ##########################################################################
${local.path_ssh_keys}
user: ${var.vm_username}

############################################## ec2 public ips #############################################################################
${local.aws_profile} aws ec2 describe-instances --instance-ids $(${local.aws_profile} aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[]| select( .Tags[].Value == "${var.cluster_name}").Instances[].InstanceId') | jq -r '.Reservations[].Instances[].PublicIpAddress'


############################################## deploy url     #############################################################################
${aws_lambda_function_url.deploy_lambda_url.function_url}


##############################################      state     #############################################################################
${local.aws_profile} aws s3api get-object --bucket ${local.state_bucket_name} --key state /dev/stdout

############################################## cluster password ###########################################################################
${local.aws_profile} aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.weka_password.id} --query SecretString --output text

EOT
}
