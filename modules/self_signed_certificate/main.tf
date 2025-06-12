resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 336  # 2 weeks
  is_ca_certificate     = false

  # Subject information is required for ACM
  subject {
    common_name  = var.common_name
    organization = var.organization
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "this" {
  private_key       = tls_private_key.this.private_key_pem
  certificate_body  = tls_self_signed_cert.this.cert_pem
  certificate_chain = null

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
