# Define the EC2 instances
resource "aws_instance" "cst_scenario_backend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  count                       = var.instance_count
  subnet_id                   = local.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [local.security_group_id]
  key_name                    = aws_key_pair.autodestroy_keypair.key_name

  # User data script
  user_data = <<-EOF
             # Set hostname
             sudo hostnamectl set-hostname weka${count.index + 2}

             EOF

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 50
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "/dev/xvdb"
    volume_type           = "gp2"
    volume_size           = 500
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.name_prefix}-${random_pet.fun-name.id}-${count.index + 2}"
    "AutoDestroy" = "true"
    Lab = "CST-Scenario-lab"
  }
}

# Additional network interfaces
resource "aws_network_interface" "private_nic1" {
  count            = var.instance_count
  subnet_id        = var.private_subnet_id
  security_groups  = [var.security_group_id]
  description      = "Private NIC 1"
}

resource "aws_network_interface" "private_nic2" {
  count            = var.instance_count
  subnet_id        = var.private_subnet_id
  security_groups  = [var.security_group_id]
  description      = "Private NIC 2"
}

resource "aws_network_interface" "private_nic3" {
  count            = var.instance_count
  subnet_id        = var.private_subnet_id
  security_groups  = [var.security_group_id]
  description      = "Private NIC 3"
}

# Attach network interfaces
resource "aws_network_interface_attachment" "nic1_attachment" {
  count                = var.instance_count
  instance_id          = aws_instance.cst_scenario_backend[count.index].id
  network_interface_id = aws_network_interface.private_nic1[count.index].id
  device_index         = 1
}

resource "aws_network_interface_attachment" "nic2_attachment" {
  count                = var.instance_count
  instance_id          = aws_instance.cst_scenario_backend[count.index].id
  network_interface_id = aws_network_interface.private_nic2[count.index].id
  device_index         = 2
}

resource "aws_network_interface_attachment" "nic3_attachment" {
  count                = var.instance_count
  instance_id          = aws_instance.cst_scenario_backend[count.index].id
  network_interface_id = aws_network_interface.private_nic3[count.index].id
  device_index         = 3
}

# Output private IPs and hostnames for external processing
output "host_entries" {
  value = [
    for index, ip in aws_instance.cst_scenario_backend : "${ip.private_ip} weka${index + 2}"
  ]
}
