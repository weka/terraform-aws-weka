data "aws_route53_zone" "domain" {
  name = var.acm_domain_name
}

locals {
  # Merge user-provided tags with required aws-apn-id tag
  tags = merge(
    var.tags_map,
    {
      aws-apn-id = "pc:epkj0ftddjwa38m3oq9umjjlm"
    }
  )
}

resource "aws_acm_certificate" "acm_certificate_request" {
  domain_name               = var.acm_domain_name
  subject_alternative_names = ["*.${var.acm_domain_name}"]
  validation_method         = "DNS"

  tags = merge(local.tags, {
    Name = var.acm_domain_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate_request.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id         = data.aws_route53_zone.domain.id
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
  certificate_arn         = aws_acm_certificate.acm_certificate_request.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
}
