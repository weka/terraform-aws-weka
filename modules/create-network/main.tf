provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.prefix}-vpc"
    Environment = var.prefix
  }
}

# Subnets
# Internet Gateway for Public Subnet
resource "aws_internet_gateway" "ig" {
  count  = var.private_network == false ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.prefix}-igw"
    Environment = var.prefix
  }
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.ig]
}

# NAT
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.subnet.*.id, 0)

  tags = {
    Name        = "${var.prefix}-nat"
    Environment = var.prefix
  }
}

locals {
  map_public_ip = var.private_network == false ? true : false
}

# Public subnet
resource "aws_subnet" "subnet" {
  count                   = length(var.subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnets_cidr[count.index]
  availability_zone       = "${var.region}${var.availability_zones[count.index]}"
  map_public_ip_on_launch = local.map_public_ip

  tags = {
    Name        = "${var.prefix}-subnet-${count.index}"
    Environment = var.prefix
    Zone        = var.availability_zones[count.index]
  }
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "${var.prefix}-route-table"
    Environment = var.prefix
  }
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  count                  = var.private_network == false ? 1: 0
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig[0].id
}

# Route for NAT
resource "aws_route" "private_nat_gateway" {
  count                  = var.private_network == true ? 1: 0
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "rt_association" {
  count          = length(var.subnets_cidr)
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.rt.id
}

# Default Security Group of VPC
resource "aws_security_group" "sg" {
  count       = var.create_sg == true ? 1 : 0
  name        = "${var.prefix}-sg"
  description = "Default SG to allow traffic from the VPC"
  vpc_id      = aws_vpc.vpc.id
  depends_on = [
    aws_vpc.vpc
  ]

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
    cidr_blocks = var.allow_ssh_from_ips
  }
  ingress {
    from_port   = 14000
    to_port     = 14000
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_from_ips
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = "true"
  }
  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.prefix
    Name        = "${var.prefix}-sg"
  }
}