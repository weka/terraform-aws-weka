resource "aws_instance" "cst-scenario-test" {
  ami           = var.ami_id
  instance_type = var.instance_type
  count         = var.instance_count
  subnet_id	= aws_subnet.private.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.cst-scenario-base-sg.id]


  tags = {
    Name = "cst-scenario-test-${count.index + 1}"
    AutoDestroy = var.autodestroy
  }
}
