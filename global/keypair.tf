# Generate a unique RSA private key
resource "tls_private_key" "autodestroy_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generate a unique suffix for the key pair name
resource "random_pet" "keypair_suffix" {
  length = 2
}

# Create an EC2 key pair with the generated OpenSSH-format public key
resource "aws_key_pair" "autodestroy_keypair" {
  key_name   = "AutoDestroyKeyPair-${random_pet.keypair_suffix.id}"
  public_key = tls_private_key.autodestroy_key.public_key_openssh  # Use OpenSSH format

  tags = {
    "AutoDestroy" = "true"
  }
}

resource "local_file" "autodestroy_private_key" {
  content  = tls_private_key.autodestroy_key.private_key_pem
  filename = "${path.module}/autodestroy_key.pem"
  file_permission = "0600"  # Set secure permissions
}
