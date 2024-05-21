output "gateways_name" {
  value       = var.gateways_name
  description = "Protocol gateway name"
}

output "instance_ids" {
  value       = aws_instance.this.*.id
  description = "Protocol gateway id"
}
