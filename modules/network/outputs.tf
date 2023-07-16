output "subnet_ids" {
  value = var.private_network ? aws_subnet.private_subnet.*.id : aws_subnet.public_subnet.*.id
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}