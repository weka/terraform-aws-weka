resource "aws_instance" "cst-scenario-test" {
  ami           = var.ami_id
  instance_type = var.instance_type
  count         = var.instance_count
  subnet_id	= aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.cst-scenario-base-sg.id]
  key_name = aws_key_pair.autodestroy_keypair.key_name


  tags = {
    Name = "cst-scenario-test-${count.index + 1}"
    "${var.expiration_tag_key}" = var.expiration_tag_value
  }
}
