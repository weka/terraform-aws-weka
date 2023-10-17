locals {
  create_ec2_endpoint        = var.create_ec2_endpoint ? 1 : 0
  create_s3_gateway_endpoint = var.create_s3_gateway_endpoint ? 1 : 0
  create_proxy_endpoint      = var.create_proxy_endpoint ? 1 : 0
}


# Endpoint Security Group
resource "aws_security_group" "this" {
  name        = "${var.prefix}-endpoint-sg"
  description = "Private link endpoint connection"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = range(local.create_proxy_endpoint)
    content {
      from_port   = "1080"
      to_port     = "1080"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "proxy endpoint connection"
    }
  }
  dynamic "ingress" {
    for_each = range(local.create_ec2_endpoint)
    content {
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      description = "ec2 endpoint connection"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.prefix
    Name        = "${var.prefix}-private-link-endpoint-sg"
  }
}

# ec2 endpoint
resource "aws_vpc_endpoint" "ec2_endpoint" {
  count               = var.create_ec2_endpoint ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.this.id]
  subnet_ids          = var.subnet_ids
  private_dns_enabled = true
  tags = {
    Name        = "${var.prefix}-ec2-endpoint"
    Environment = var.prefix
  }
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# s3 endpoint
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  count               = var.create_s3_gateway_endpoint ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = [data.aws_vpc.this.main_route_table_id]
  tags = {
    Name        = "${var.prefix}-s3-gateway-endpoint"
    Environment = var.prefix
  }
}

# proxy endpoint
resource "aws_vpc_endpoint" "proxy_endpoint" {
  count               = var.create_proxy_endpoint ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = lookup(var.region_map, var.region)
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.this.id]
  subnet_ids          = var.subnet_ids
  private_dns_enabled = true
  tags = {
    Name        = "${var.prefix}-proxy-endpoint"
    Environment = var.prefix
  }
}

resource "aws_vpc_endpoint_security_group_association" "this" {
  count             = var.create_proxy_endpoint || var.create_ec2_endpoint ? 1 : 0
  vpc_endpoint_id   = aws_vpc_endpoint.proxy_endpoint[0].id
  security_group_id = aws_security_group.this.id
}

resource "aws_vpc_endpoint" "lambda_endpoint" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.lambda"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = var.sg_ids
  subnet_ids          = var.subnet_ids
  private_dns_enabled = true
  tags = {
    Name        = "${var.prefix}-lambda-endpoint"
    Environment = var.prefix
  }
}