output "clients_name" {
  value       = var.clients_name
  description = "Name of clients"
}

locals {
  ips_type       = var.assign_public_ip ? "PublicIpAddress" : "PrivateIpAddress"
  asg_name       = var.use_autoscaling_group ? aws_autoscaling_group.autoscaling_group[0].name : ""
  asg_ips_cmd    = <<EOT
aws ec2 describe-instances --instance-ids $(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name ${local.asg_name} --query "AutoScalingGroups[].Instances[].InstanceId" --output text) --query 'Reservations[].Instances[].${local.ips_type}' --output json
EOT
  asg_ips_helper = var.use_autoscaling_group ? local.asg_ips_cmd : null

  public_ips = var.use_autoscaling_group ? null : [
    for i in range(var.clients_number) :
    aws_instance.this[i].public_ip
  ]
  private_ips = var.use_autoscaling_group ? null : [
    for i in range(var.clients_number) :
    aws_instance.this[i].private_ip
  ]
}

output "client_helper_commands" {
  value = local.asg_ips_helper
}

output "asg_name" {
  value       = local.asg_name == "" ? null : local.asg_name
  description = "Name of ASG"
}

output "client_ips" {
  value       = var.clients_number == 0 ? null : var.assign_public_ip ? local.public_ips : local.private_ips
  description = "Ips of clients"
}
