# Use the existing VPC ID directly
locals {
  vpc_id = "vpc-0127ecb47d3ac481c"  # Replace with your actual VPC ID
}

resource "aws_security_group" "cst_scenario_base_sg" {
  vpc_id = local.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cst-scenario-base-sg"
  }
}

# Use the existing Internet Gateway ID directly
locals {
  internet_gateway_id = "igw-0abcdef1234567890"  # Replace with your actual IGW ID
}

# Use the existing Subnet IDs directly
locals {
  subnet_ids = ["subnet-0abcdef1234567890"]  # Replace with your actual Subnet IDs
}
