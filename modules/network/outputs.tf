locals {
  subnet_ids       = var.private_network ? aws_subnet.private_subnet[*].id : aws_subnet.public_subnet[*].id
  subnet_ids_count = length(local.subnet_ids)
}

output "subnet_ids" {
  value = var.additional_subnet ? slice(local.subnet_ids, 0, local.subnet_ids_count - 1) : local.subnet_ids
}

output "additional_subnet_id" {
  value = local.subnet_ids[local.subnet_ids_count - 1]
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}
