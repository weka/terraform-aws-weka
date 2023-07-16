data aws_region current {}

locals {
  region = data.aws_region.current.name
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
# Internet Gateway (required for Public Subnet and NAT)
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags   = {
    Name        = "${var.prefix}-igw"
    Environment = var.prefix
  }
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  count      = var.private_network ? 1 : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.ig]
}

# NAT
resource "aws_nat_gateway" "nat" {
  count         = var.private_network ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = element(aws_subnet.subnet.*.id, 0)

  tags = {
    Name        = "${var.prefix}-nat"
    Environment = var.prefix
  }
}

# Public subnet
resource "aws_subnet" "subnet" {
  count                   = length(var.subnets_cidr)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnets_cidr[count.index]
  availability_zone       = "${local.region}${var.availability_zones[count.index]}"
  map_public_ip_on_launch = var.assign_public_ip

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
  count                  = var.private_network ? 0 : 1
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

# Route for NAT
resource "aws_route" "private_nat_gateway" {
  count                  = var.private_network ? 1 : 0
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "rt_association" {
  count          = length(var.subnets_cidr)
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.rt.id
}
