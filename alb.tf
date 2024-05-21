resource "aws_lb" "alb" {
  count                            = var.create_alb ? 1 : 0
  name                             = substr("${var.prefix}-${var.cluster_name}-lb", 0, 32)
  internal                         = true
  load_balancer_type               = "application"
  security_groups                  = local.alb_sg_ids
  subnets                          = concat(local.subnet_ids, [local.additional_subnet_id])
  enable_cross_zone_load_balancing = false
  enable_deletion_protection       = false
  tags = {
    Name         = "${var.prefix}-${var.cluster_name}-lb"
    cluster_name = var.cluster_name
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  count    = var.create_alb ? 1 : 0
  name     = substr("${var.prefix}-${var.cluster_name}-lb-target-group", 0, 32)
  vpc_id   = local.vpc_id
  port     = 14000
  protocol = "HTTP"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    protocol            = "HTTP"
    port                = "14000"
    path                = "/api/v2/healthcheck/"
  }
  tags = {
    Name = "${var.prefix}-${var.cluster_name}-lb-target-group"
  }
}

resource "aws_lb_listener" "lb_http_listener" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.alb_target_group[0].id
    type             = "forward"
  }
  tags = {
    Name = "${var.prefix}-${var.cluster_name}-lb-listener"
  }
}

data "aws_route53_zone" "domain" {
  count = var.create_alb &&  var.alb_acm_domain_name != "" ? 1 : 0
  name  = var.alb_acm_domain_name
}

resource "aws_acm_certificate"  "acm_certificate_request" {
  count                     = var.create_alb && var.alb_cert_arn == null && var.alb_acm_domain_name != "" ? 1 : 0
  domain_name               = var.alb_acm_domain_name
  subject_alternative_names = ["*.${var.alb_acm_domain_name}"]
  validation_method         = "DNS"

  tags = {
    Name : var.alb_acm_domain_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation_record" {
  for_each = var.create_alb && var.alb_cert_arn == null && var.alb_acm_domain_name != "" ? {
    for dvo in aws_acm_certificate.acm_certificate_request[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }  : { }
  zone_id         = data.aws_route53_zone.domain[0].id
  name            = each.value.name
  type            = each.value.type
  allow_overwrite = true
  records         = [each.value.record]
  ttl             = 300
  depends_on      = [aws_acm_certificate.acm_certificate_request]
}

resource "aws_acm_certificate_validation" "acm_certificate_validation" {
  count = var.create_alb && var.alb_cert_arn == null && var.alb_acm_domain_name != "" ? 1 : 0
  timeouts {
    create = "7m"
  }
  certificate_arn         = aws_acm_certificate.acm_certificate_request[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
}

resource "aws_lb_listener" "lb_https_listener" {
  count             = var.create_alb && (var.alb_cert_arn != null || var.alb_acm_domain_name != "") ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.alb_cert_arn == null ? aws_acm_certificate.acm_certificate_request[0].arn : var.alb_cert_arn

  default_action {
    target_group_arn = aws_lb_target_group.alb_target_group[0].id
    type             = "forward"
  }
  tags = {
    Name = "${var.prefix}-${var.cluster_name}-lb-https-listener"
  }
  depends_on = [aws_acm_certificate.acm_certificate_request,aws_lb.alb,aws_lb_target_group.alb_target_group ]
}

resource "aws_autoscaling_attachment" "alb_autoscaling_attachment" {
  count                  = var.create_alb ? 1 : 0
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  lb_target_group_arn    = aws_lb_target_group.alb_target_group[0].arn
  depends_on             = [aws_autoscaling_group.autoscaling_group]
}

resource "aws_route53_record" "lb_record" {
  count = var.alb_alias_name != "" ? 1 : 0
  name  = var.alb_alias_name
  type  = "A"
  alias {
    evaluate_target_health = true
    name                   = aws_lb.alb[0].dns_name
    zone_id                = aws_lb.alb[0].zone_id
  }
  zone_id    = data.aws_route53_zone.domain[0].id
  depends_on = [aws_lb.alb]
}
