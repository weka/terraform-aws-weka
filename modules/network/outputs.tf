locals {
  public_subnet_ids  = aws_subnet.public_subnet[*].id
  private_subnet_ids = var.subnet_autocreate_as_private ? aws_subnet.private_subnet[*].id : []
  all_subnets_ids        = var.subnet_autocreate_as_private ? local.private_subnet_ids : local.public_subnet_ids
  subnet_ids_count   = length(local.all_subnets_ids)
  deployment_subnet_ids = var.additional_subnet ? slice(local.all_subnets_ids, 0, local.subnet_ids_count - 1) : local.all_subnets_ids
  additional_subnet_id =  var.additional_subnet ? local.all_subnets_ids[local.subnet_ids_count - 1]: null
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
  value       = coalesce(local.deployment_subnet_ids, [])
  description = "List of subnet ids without the `additional subnet`"
}

output "additional_subnet_id" {
  value       = local.additional_subnet_id
  description = "Additional subnet id"
}

output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "Vpc id"
}
