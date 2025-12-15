locals {
  # Merge user-provided tags with required aws-apn-id tag
  tags = merge(
    var.tags_map,
    {
      aws-apn-id = "pc:epkj0ftddjwa38m3oq9umjjlm"
    }
  )
}

# vpc endpoint proxy security group
resource "aws_security_group" "proxy_sg" {
  count       = var.create_vpc_endpoint_proxy ? 1 : 0
  name        = "${var.prefix}-endpoint-sg"
  description = "Private link endpoint connection"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "1080"
    to_port     = "1080"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "proxy endpoint connection"
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Environment = var.prefix
    Name        = "${var.prefix}-proxy-vpc-endpoint-sg"
  })
}

data "aws_route_table" "subnet" {
  subnet_id = var.subnet_id
}

# ec2 vpc endpoint proxy security group
resource "aws_security_group" "ec2_endpoint_sg" {
  count       = var.create_vpc_endpoint_ec2 ? 1 : 0
  name        = "${var.prefix}-ec2-vpc-endpoint-sg"
  description = "Ec2 vpc endpoint connection"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    description = "ec2 endpoint connection"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Environment = var.prefix
    Name        = "${var.prefix}-ec2-vpc-endpoint-sg"
  })
}
# ec2 endpoint
resource "aws_vpc_endpoint" "ec2_endpoint" {
  count               = var.create_vpc_endpoint_ec2 ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ec2_endpoint_sg[0].id]
  subnet_ids          = [var.subnet_id]
  private_dns_enabled = true
  tags = merge(local.tags, {
    Name        = "${var.prefix}-ec2-endpoint"
    Environment = var.prefix
  })
  depends_on = [aws_security_group.ec2_endpoint_sg]
}

# s3 endpoint
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  count             = var.create_vpc_endpoint_s3_gateway ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [data.aws_route_table.subnet.route_table_id]
  tags = merge(local.tags, {
    Name        = "${var.prefix}-s3-gateway-endpoint"
    Environment = var.prefix
  })
}

# proxy endpoint
resource "aws_vpc_endpoint" "proxy_endpoint" {
  count               = var.create_vpc_endpoint_proxy ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = lookup(var.region_map, var.region)
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.proxy_sg[0].id]
  subnet_ids          = [var.subnet_id]
  private_dns_enabled = true
  tags = merge(local.tags, {
    Name        = "${var.prefix}-proxy-endpoint"
    Environment = var.prefix
  })
}

resource "aws_vpc_endpoint_security_group_association" "proxy_association_sg" {
  count             = var.create_vpc_endpoint_proxy ? 1 : 0
  vpc_endpoint_id   = aws_vpc_endpoint.proxy_endpoint[0].id
  security_group_id = aws_security_group.proxy_sg[0].id
}

resource "aws_vpc_endpoint_security_group_association" "ec2_association_sg" {
  count             = var.create_vpc_endpoint_ec2 ? 1 : 0
  vpc_endpoint_id   = aws_vpc_endpoint.ec2_endpoint[0].id
  security_group_id = aws_security_group.ec2_endpoint_sg[0].id
}

resource "aws_vpc_endpoint" "lambda_endpoint" {
  count               = var.create_vpc_endpoint_lambda ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.lambda"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ec2_endpoint_sg[0].id]
  subnet_ids          = [var.subnet_id]
  private_dns_enabled = true
  tags = merge(local.tags, {
    Name        = "${var.prefix}-lambda-endpoint"
    Environment = var.prefix
  })
}

resource "aws_vpc_endpoint" "dynamodb_endpoint_gtw" {
  count             = var.create_vpc_endpoint_dynamodb_gateway ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [data.aws_route_table.subnet.route_table_id]

  tags = merge(local.tags, {
    Name        = "${var.prefix}-dynamodb-gateway-endpoint"
    Environment = var.prefix
  })
}


resource "aws_vpc_endpoint" "autoscaling_endpoint" {
  count               = var.create_vpc_endpoint_autoscaling ? 1 : 0
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.autoscaling"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ec2_endpoint_sg[0].id]
  subnet_ids          = [var.subnet_id]
  private_dns_enabled = true
  tags = merge(local.tags, {
    Name        = "${var.prefix}-autoscaling-endpoint"
    Environment = var.prefix
  })
}
