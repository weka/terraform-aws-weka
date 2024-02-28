data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  additional_subnet       = var.additional_subnet ? [var.alb_additional_subnet_cidr_block] : []
  subnets_cidrs           = concat(var.subnets_cidrs, local.additional_subnet)
  nat_public_subnet_cidr  = var.create_nat_gateway ? [var.nat_public_subnet_cidr] : []
  availability_zones_list = var.additional_subnet || var.create_nat_gateway ? distinct(flatten([var.availability_zones, data.aws_availability_zones.available[*].names])) : var.availability_zones
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
  count  = var.subnet_autocreate_as_private ? 0 : 1
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name        = "${var.prefix}-igw"
    Environment = var.prefix
  }
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  count      = var.create_nat_gateway ? 1 : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.ig]
}

resource "aws_route_table" "ig_route_table" {
  count  = var.subnet_autocreate_as_private ? 0 : 1
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig[0].id
  }

  tags = {
    Name        = "${var.prefix}-igw-rt"
    Environment = var.prefix
  }
  depends_on = [aws_vpc.vpc, aws_internet_gateway.ig]
}

# NAT
resource "aws_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  subnet_id     = element(aws_subnet.public_subnet[*].id, 0)
  allocation_id = aws_eip.nat_eip[0].id
  tags = {
    Name        = "${var.prefix}-private-nat"
    Environment = var.prefix
  }
}

resource "aws_route_table" "nat_route_table" {
  count  = var.create_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name        = "${var.prefix}-nat-rt"
    Environment = var.prefix
  }
  depends_on = [aws_vpc.vpc, aws_nat_gateway.nat]
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  count                   = !var.subnet_autocreate_as_private ? var.create_nat_gateway ? length(local.nat_public_subnet_cidr) : length(local.subnets_cidrs) : 0
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.create_nat_gateway ? local.nat_public_subnet_cidr[count.index] : local.subnets_cidrs[count.index]
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
  count          = var.subnet_autocreate_as_private ? 0 : length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.ig_route_table[0].id
  depends_on     = [aws_subnet.public_subnet, aws_route_table.ig_route_table]
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  count                   = var.subnet_autocreate_as_private || var.create_nat_gateway ? length(local.subnets_cidrs) : 0
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.subnets_cidrs[count.index]
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
  count          = var.create_nat_gateway ? length(aws_subnet.private_subnet[*].id) : 0
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = var.subnet_autocreate_as_private ? aws_vpc.vpc.default_route_table_id : aws_route_table.nat_route_table[0].id
  depends_on     = [aws_subnet.private_subnet, aws_route_table.nat_route_table]
}
