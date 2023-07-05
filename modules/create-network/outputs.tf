output "subnets" {
  value = aws_subnet.subnet.*.id
}

output "sg-id" {
  value = var.create_sg ? [aws_security_group.sg[0].id] : []
}