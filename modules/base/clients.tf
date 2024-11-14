# Define the EC2 instances
resource "aws_instance" "cst_scenario_client" {
  ami                         = var.ami_id
  instance_type               = var.client_instance_type
  count                       = var.client_instance_count
  subnet_id                   = local.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [local.security_group_id]
  key_name                    = aws_key_pair.autodestroy_keypair.key_name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 50
    delete_on_termination = true
  }

  tags = {
    Name        = "client-${var.name_prefix}-${random_pet.fun-name.id}-${count.index}"
    "AutoDestroy" = "true"
    Lab = "CST-Scenario-lab"
  }
}

# Additional network interfaces
resource "aws_network_interface" "client_private_nic1" {
  count            = var.client_instance_count
  subnet_id        = var.private_subnet_id
  security_groups  = [var.security_group_id]
  description      = "Private NIC 1"
}

# Attach network interfaces
resource "aws_network_interface_attachment" "client_nic1_attachment" {
  count                = var.client_instance_count
  instance_id          = aws_instance.cst_scenario_client[count.index].id
  network_interface_id = aws_network_interface.private_nic1[count.index].id
  device_index         = 1
}

