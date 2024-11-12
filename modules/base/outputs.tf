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
