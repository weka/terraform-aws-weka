# resource "aws_subnet" "private" {
#    vpc_id = aws_vpc.main.id
#    cidr_block = "10.11.0.0/19"
#tags = {
#    "Name" = "CST-Scenario-Subnet-1"
#    }
#}

#Create a Public Subnet with automatic public IP assignment
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.0.0/24"
  map_public_ip_on_launch = true
}
