locals {
  public_subnet_ids  = aws_subnet.public_subnet[*].id
  private_subnet_ids = var.private_network ? aws_subnet.private_subnet[*].id : []
  subnets_ids        = var.private_network ? concat(local.public_subnet_ids, local.private_subnet_ids) : local.public_subnet_ids
  subnet_ids_count   = length(local.subnets_ids)
}

output "private_subnets" {
  value = local.private_subnet_ids
}

output "public_subnets" {
  value = local.public_subnet_ids
}

output "subnet_ids" {
  value = var.additional_subnet ? slice(local.subnets_ids, 0, local.subnet_ids_count - 1) : local.subnets_ids
}

output "additional_subnet_id" {
  value = local.subnets_ids[local.subnet_ids_count - 1]
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}
