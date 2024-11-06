resource "aws_instance" "cst-scenario-test" {
  ami           = var.ami_id
  instance_type = var.instance_type
  count         = var.instance_count
  subnet_id	= "subnet-041fbb944f79e6f99"
  associate_public_ip_address = true
  vpc_security_group_ids = ["sg-0734316b8d192a303"]
  key_name = aws_key_pair.autodestroy_keypair.key_name


  tags = {
    Name = "${var.name_prefix}-${random_pet.keypair_suffix.id}-${count.index + 1}"
    "${var.expiration_tag_key}" = var.expiration_tag_value
  }
}
