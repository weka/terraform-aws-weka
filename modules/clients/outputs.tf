output "clients_name" {
  value = var.clients_name
}

output "client_ips" {
  value = var.clients_number == 0 ? null : var.assign_public_ip ? aws_instance.this.*.public_ip : aws_instance.this.*.private_ip
}
