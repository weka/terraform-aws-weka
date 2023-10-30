output "ec2_endpoint_sg_id" {
  value       = aws_security_group.ec2_endpoint_sg[0].id
  description = "Vpc endpoint ec2 sg id"
}

output "proxy_endpoint_sg_id" {
  value       = aws_security_group.proxy_sg[0].id
  description = "Vpc endpoint proxy sg id"
}
