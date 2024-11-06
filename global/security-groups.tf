resource "aws_security_group" "cst-scenario-base-sg" {
  name        = "cst-scenario-base-security-group"
  description = "Allow communication to basic ports for ssh and weka"

  vpc_id = aws_vpc.main.id  

  # inbound SSH access (port 22) from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Opens weka to all
  ingress {
    from_port   = 14000
    to_port     = 14000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   # Opens weka to all
  ingress {
    from_port   = 14000
    to_port     = 14000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Rule to allow all traffic from within VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.subnet_cidr]
  }


  # Example for allowing all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
