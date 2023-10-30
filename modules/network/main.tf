data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  region                  = data.aws_region.current.name
  public_subnets          = var.additional_subnet && !var.subnet_autocreate_as_private ? concat(var.public_subnets_cidr, [var.alb_additional_subnet_cidr_block]) : var.public_subnets_cidr
  private_subnets         = var.additional_subnet && var.subnet_autocreate_as_private ? concat(var.private_subnets_cidr, [var.alb_additional_subnet_cidr_block]) : var.private_subnets_cidr
  availability_zones_list = var.additional_subnet ? distinct(flatten([var.availability_zones, data.aws_availability_zones.available[*].names])) : var.availability_zones
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
  tags = {
    Name        = "${var.prefix}-igw"
    Environment = var.prefix
  }
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  count      = var.subnet_autocreate_as_private ? 1 : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.ig]
}

resource "aws_route_table" "ig_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  tags = {
    Name        = "${var.prefix}-igw-rt"
    Environment = var.prefix
  }
  depends_on = [aws_vpc.vpc, aws_internet_gateway.ig]
}

# NAT
resource "aws_nat_gateway" "nat" {
  count         = var.subnet_autocreate_as_private ? 1 : 0
  subnet_id     = element(aws_subnet.public_subnet[*].id, 0)
  allocation_id = aws_eip.nat_eip[0].id
  tags = {
    Name        = "${var.prefix}-private-nat"
    Environment = var.prefix
  }
}

resource "aws_route_table" "nat_route_table" {
  count  = var.subnet_autocreate_as_private ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name        = "${var.prefix}-nat-rt"
    Environment = var.prefix
  }
  depends_on = [aws_vpc.vpc, aws_nat_gateway.nat]
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  count                   = length(local.public_subnets)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.availability_zones_list[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.prefix}-public-subnet-${count.index}"
    Environment = var.prefix
    Zone        = local.availability_zones_list[count.index]
  }
}

# associate route table to public subnet
resource "aws_route_table_association" "public_rt_associate" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.ig_route_table.id
  depends_on     = [aws_subnet.public_subnet, aws_route_table.ig_route_table]
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  count                   = var.subnet_autocreate_as_private ? length(local.private_subnets) : 0
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.private_subnets[count.index]
  availability_zone       = local.availability_zones_list[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.prefix}-private-subnet-${count.index}"
    Environment = var.prefix
    Zone        = local.availability_zones_list[count.index]
  }
}

# associate route table to private subnet
resource "aws_route_table_association" "private_rt_associate" {
  count          = var.subnet_autocreate_as_private ? length(var.private_subnets_cidr) : 0
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.nat_route_table[0].id
  depends_on     = [aws_subnet.private_subnet, aws_route_table.nat_route_table]
}
