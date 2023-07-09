output "subnet_ids" {
  value = aws_subnet.subnet.*.id
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}