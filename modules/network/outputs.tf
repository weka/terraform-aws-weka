locals {
  public_subnet_ids  = aws_subnet.public_subnet[*].id
  private_subnet_ids = var.subnet_autocreate_as_private ? aws_subnet.private_subnet[*].id : []
  subnets_ids        = var.subnet_autocreate_as_private ? local.private_subnet_ids : local.public_subnet_ids
  subnet_ids_count   = length(local.subnets_ids)
}

output "private_subnets" {
  value       = local.private_subnet_ids
  description = "Private subnet ids"
}

output "public_subnets" {
  value       = local.public_subnet_ids
  description = "Public subnet ids"
}

output "subnet_ids" {
  value       = var.additional_subnet ? slice(local.subnets_ids, 0, local.subnet_ids_count - 1) : local.subnets_ids
  description = "List of subnet ids without the `additional subnet`"
}

output "additional_subnet_id" {
  value       = local.subnets_ids[local.subnet_ids_count - 1]
  description = "Additional subnet id"
}

output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "Vpc id"
}
