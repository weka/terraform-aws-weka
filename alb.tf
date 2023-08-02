resource "aws_lb" "alb" {
  count                            = var.create_alb ? 1 : 0
  name                             = "${var.prefix}-${var.cluster_name}-lb"
  internal                         = true
  load_balancer_type               = "application"
  security_groups                  = local.sg_ids
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
  name     = "${var.prefix}-${var.cluster_name}-lb-target-group"
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

resource "aws_lb_listener" "lb_listener" {
  count             = var.create_alb ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].id
  port              = 14000

  default_action {
    target_group_arn = aws_lb_target_group.alb_target_group[0].id
    type             = "forward"
  }
  tags = {
    Name = "${var.prefix}-${var.cluster_name}-lb-listener"
  }
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
    evaluate_target_health = false
    name                   = aws_lb.alb[0].dns_name
    zone_id                = aws_lb.alb[0].zone_id
  }
  zone_id    = var.route53_zone_id
  depends_on = [aws_lb.alb]
}
