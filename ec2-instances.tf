locals {
  public_ip               = var.private_network == false ? 0 : 1
  ssh_path                = "/tmp/${var.prefix}-${var.cluster_name}"
  nics                    = var.container_number_map[var.instance_type].nics
  private_nic_first_index = var.private_network ? 0 : 1
  public_ssh_key          = var.ssh_public_key_path == null ? tls_private_key.key[0].public_key_openssh : file(var.ssh_public_key_path)
  private_ssh_key         = var.ssh_private_key_path == null ? tls_private_key.key[0].private_key_pem : file(var.ssh_private_key_path)
  install_weka_script_path = "${path.module}/install_weka.sh"

  install_weka_script = templatefile(local.install_weka_script_path,
    {
      token             = var.get_weka_io_token
      weka_version      = var.weka_version
      install_weka_url  = var.install_weka_url
    })

  deploy_script = templatefile("${path.module}/deploy.sh", {
    apt_repo_url = var.apt_repo_url
    memory = var.container_number_map[var.instance_type].memory
    compute_num = var.add_frontend_container ? var.container_number_map[var.instance_type].compute : var.container_number_map[var.instance_type].compute + 1
    frontend_num = var.container_number_map[var.instance_type].frontend
    drive_num = var.container_number_map[var.instance_type].drive
    nics_num = var.container_number_map[var.instance_type].nics
    install_dpdk    = true
    subnet_prefixes = data.aws_subnet.subnets[0].cidr_block
  })

  custom_data_parts = [
    local.install_weka_script, local.deploy_script
  ]
  custom_data = join("\n", local.custom_data_parts)
}

data "aws_ami" "amzn_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.*-x86_64-gp2"]
  }
}

data "aws_subnet" "subnets" {
  count = length(var.subnets)
  id    = var.subnets[count.index]
}

# =============== ssh key ===================
resource "tls_private_key" "key" {
  count     = var.ssh_private_key_path == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  count      = var.ssh_public_key_path == null ? 1 : 0
  key_name   = "${var.prefix}-${var.cluster_name}-ssh-key"
  public_key = tls_private_key.key[0].public_key_openssh
}

resource "local_file" "public_key" {
  count           = var.ssh_public_key_path == null ? 1 : 0
  content         = tls_private_key.key[count.index].public_key_openssh
  filename        = "${local.ssh_path}-public-key.pub"
  file_permission = "0600"
}

resource "local_file" "private_key" {
  count           = var.ssh_private_key_path == null ? 1 : 0
  content         = tls_private_key.key[count.index].private_key_pem
  filename        = "${local.ssh_path}-private-key.pem"
  file_permission = "0600"
}


resource "aws_placement_group" "placement_group" {
  count      = var.placement_group_name == null ? 1 : 0
  name       = "${var.prefix}-${var.cluster_name}-placement-group"
  strategy   = "cluster"
}

resource "aws_launch_template" "launch_template" {
  name = "${var.prefix}-${var.cluster_name}-backend"

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = var.disk_size
      volume_type = "gp3"
      delete_on_termination = true
    }
  }

  credit_specification {
    cpu_credits = "standard"
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  disable_api_stop                     = true
  disable_api_termination              = true
  ebs_optimized                        = true
  image_id                             = data.aws_ami.amzn_ami.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  key_name                             = var.ssh_public_key_path == null ? aws_key_pair.generated_key[0].key_name : null

 # license_specification {
  #  license_configuration_arn = "arn:aws:license-manager:eu-west-1:123456789012:license-configuration:lic-0123456789abcdef0123456789abcdef"
  #}

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  dynamic "network_interfaces" {
    for_each = range(0,local.nics)
    content {
      subnet_id             = data.aws_subnet.subnets[0].id
      security_groups       = var.sg_id
      device_index          = network_interfaces.value
      delete_on_termination = true
    }
  }

  placement {
    availability_zone = "${var.region}${var.availability_zones[0]}"
    group_name        = var.placement_group_name == null ? aws_placement_group.placement_group[0].name : var.placement_group_name
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.prefix}-${var.cluster_name}-backend"
    }
  }
  tags       =  merge(var.tags_map, { "weka_cluster" : var.cluster_name })
  user_data  = base64encode(local.custom_data)
  depends_on = [aws_placement_group.placement_group, aws_iam_instance_profile.instance_profile]
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                = "${var.prefix}-${var.cluster_name}-autoscaling-group"
  #availability_zones  = [ for z in var.availability_zones: format("%s%s", var.region,z) ]
  desired_capacity    = var.cluster_size
  max_size            = var.cluster_size
  min_size            = var.cluster_size
  vpc_zone_identifier = [data.aws_subnet.subnets[0].id]

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }
  #tag {
   # key                 = "${var.prefix}-${var.cluster_name}-asg"
    #propagate_at_launch = true
    #value               = var.cluster_name
  #}
  depends_on = [aws_launch_template.launch_template]
}