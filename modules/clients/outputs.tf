output "clients_name" {
  value = var.clients_name
}

locals {
  public_ips = [
    for i in range(var.var.clients_number) :
    aws_instance.this[i].public_ip
  ]
  private_ips = [
    for i in range(var.var.clients_number) :
    aws_instance.this[i].private_ip
  ]
}
output "client_ips" {
  value = var.clients_number == 0 ? null : var.assign_public_ip ? local.public_ips : local.private_ips
}
