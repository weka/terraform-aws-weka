# Generate a unique RSA private key
resource "tls_private_key" "autodestroy_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an EC2 key pair with the generated OpenSSH-format public key
resource "aws_key_pair" "autodestroy_keypair" {
  key_name   = "AutoDestroyKeyPair-${random_pet.fun-name.id}"
  public_key = tls_private_key.autodestroy_key.public_key_openssh  # Use OpenSSH format

  tags = {
    "AutoDestroy" = "true"
  }
}
