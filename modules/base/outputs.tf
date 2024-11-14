# Output the private key for access
output "private_key" {
  description = "The private key for the EC2 key pair"
  value       = tls_private_key.autodestroy_key.private_key_pem
sensitive = true
}

output "keypair_name" {
  description = "The name of the EC2 key pair created for auto-destroy"
  value       = aws_key_pair.autodestroy_keypair.key_name
}

output "keypair_fingerprint" {
  description = "The fingerprint of the EC2 key pair"
  value       = aws_key_pair.autodestroy_keypair.fingerprint
}

output "private_ip_pairs" {
  value = [
    for index in range(var.instance_count) : format(
      "%s+%s",
      aws_network_interface.private_nic1[index].private_ip,
      aws_network_interface.private_nic2[index].private_ip
    )
  ]
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = var.subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = var.private_subnet_id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = var.security_group_id  # Adjust the resource name if different
}

output "random_pet_id" {
  description = "Unique identifier from random_pet"
  value       = random_pet.fun-name.id
}

output "private_key_pem" {
  description = "The private key content"
  value       = tls_private_key.autodestroy_key.private_key_pem
  sensitive   = true
}
# Output list of private IPs
output "instance_private_ips" {
  description = "List of private IPs from the other module"
  value       = [for instance in aws_instance.cst_scenario_test : instance.private_ip]
}

# Output list of public IPs
output "instance_public_ips" {
  description = "List of public IPs from the EC2 instances"
  value       = [for instance in aws_instance.cst_scenario_test : instance.public_ip]
}
