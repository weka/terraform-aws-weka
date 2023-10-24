locals {
  private_network = var.private_network ? 1 : 0
}

# Default Security Group of VPC
resource "aws_security_group" "sg" {
  name        = "${var.prefix}-sg"
  description = "Default SG to allow traffic from the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_ranges
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allow_https_ranges
  }
  ingress {
    from_port   = 14000
    to_port     = 14000
    protocol    = "tcp"
    cidr_blocks = var.allow_weka_api_ranges
  }
  dynamic "ingress" {
    for_each = range(local.private_network)
    content {
      from_port   = 1080
      to_port     = 1080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
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

  tags = {
    Environment = var.prefix
    Name        = "${var.prefix}-sg"
  }
}
