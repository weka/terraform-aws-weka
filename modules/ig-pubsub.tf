resource "aws_internet_gateway" "igw" {
  vpc_id = vpc-0127ecb47d3ac481c
}

resource "aws_route_table" "public_rt" {
  vpc_id =  vpc-0127ecb47d3ac481c

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


