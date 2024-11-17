# Default Security Group of VPC
resource "aws_security_group" "sg" {
  name        = "${var.prefix}-${var.cluster_name}-sg"
  description = "Default SG to allow traffic from the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_cidrs
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_allow_https_cidrs
  }

  dynamic "ingress" {
    for_each = var.custom_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  ingress {
    from_port   = 14000
    to_port     = 14000
    protocol    = "tcp"
    cidr_blocks = var.allow_weka_api_cidrs
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags_map, {
    Environment = var.prefix
    Name        = "${var.prefix}-${var.cluster_name}-sg"
  })
}
