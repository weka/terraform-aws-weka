# Use the existing VPC ID directly
locals {
  vpc_id = var.vpc_id
  subnet_id = var.subnet_id
  internet_gateway_id = var.internet_gateway_id
  security_group_id   = var.security_group_id 
  route_table_id    = var.route_table_id
  hostnames = [for index in range(var.instance_count) : "${var.name_prefix}-${index + 1}"]
}
