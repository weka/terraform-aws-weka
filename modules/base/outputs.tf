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
