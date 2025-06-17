output "cert_arn" {
  description = "The ARN of the ACM certificate"
  value       = aws_acm_certificate.this.arn
}

output "cert_pem" {
  description = "The PEM-encoded certificate"
  sensitive   = true
  value       = tls_self_signed_cert.this.cert_pem
}
