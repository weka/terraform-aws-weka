output "ec2_endpoint_sg_id" {
  value       = var.create_vpc_endpoint_ec2 ? aws_security_group.ec2_endpoint_sg[0].id : null
  description = "Vpc endpoint ec2 sg id"
}

output "proxy_endpoint_sg_id" {
  value       = var.create_vpc_endpoint_proxy ? aws_security_group.proxy_sg[0].id : null
  description = "Vpc endpoint proxy sg id"
}
