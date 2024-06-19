data "aws_route53_zone" "domain" {
  name = var.acm_domain_name
}

resource "aws_acm_certificate" "acm_certificate_request" {
  domain_name               = var.acm_domain_name
  subject_alternative_names = ["*.${var.acm_domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name : var.acm_domain_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate_request[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id         = data.aws_route53_zone.domain[0].id
  name            = each.value.name
  type            = each.value.type
  allow_overwrite = true
  records         = [each.value.record]
  ttl             = 300
  depends_on      = [aws_acm_certificate.acm_certificate_request]
}

resource "aws_acm_certificate_validation" "acm_certificate_validation" {
  timeouts {
    create = "7m"
  }
  certificate_arn         = aws_acm_certificate.acm_certificate_request[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
}
