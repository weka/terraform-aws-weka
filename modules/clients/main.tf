data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "selected" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.*-x86_64-gp2"]
  }
}

locals {
  region    = data.aws_region.current.name
  tags_dest = ["instance", "network-interface", "volume"]

  instance_iam_profile_arn = var.instance_iam_profile_arn != "" ? var.instance_iam_profile_arn : aws_iam_instance_profile.this[0].arn

  preparation_script = templatefile("${path.module}/init.sh", {
    proxy               = var.proxy_url
    nics_num            = var.nics
    subnet_id           = var.subnet_id
    region              = local.region
    groups              = join(" ", var.sg_ids)
    weka_log_group_name = "/wekaio/clients/${var.clients_name}"
  })

  mount_wekafs_script = templatefile("${path.module}/mount_wekafs.sh", {
    # all_subnets        = split("/", data.aws_subnet.selected.cidr_block)[0]
    all_gateways       = join(" ", [for i in range(var.nics) : cidrhost(data.aws_subnet.selected.cidr_block, 1)])
    nics_num           = var.nics
    weka_cluster_size  = var.weka_cluster_size
    weka_cluster_name  = var.weka_cluster_name
    mount_clients_dpdk = var.mount_clients_dpdk
    region             = local.region
    alb_dns_name       = var.alb_dns_name != null ? var.alb_dns_name : ""
  })

  custom_data_parts = [local.preparation_script, local.mount_wekafs_script]
  custom_data       = base64encode(join("\n", local.custom_data_parts))
}

resource "aws_placement_group" "this" {
  count    = var.placement_group_name == null ? 1 : 0
  name     = "${var.clients_name}-placement-group"
  strategy = "cluster"
}

resource "aws_launch_template" "this" {
  name_prefix                          = var.clients_name
  disable_api_termination              = false
  ebs_optimized                        = true
  image_id                             = var.ami_id != null ? var.ami_id : data.aws_ami.selected[0].id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  key_name                             = var.key_pair_name

  block_device_mappings {
    device_name = "/dev/xvda" # root device
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  credit_specification {
    cpu_credits = "standard"
  }

  iam_instance_profile {
    arn = local.instance_iam_profile_arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" #required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = var.assign_public_ip
    delete_on_termination       = true
    device_index                = 0
    security_groups             = var.sg_ids
    subnet_id                   = var.subnet_id
  }

  placement {
    availability_zone = "${local.region}${var.availability_zone}"
    group_name        = var.placement_group_name == null ? aws_placement_group.this[0].name : var.placement_group_name
  }

  dynamic "tag_specifications" {
    for_each = local.tags_dest
    content {
      resource_type = tag_specifications.value
      tags = merge(var.tags_map, {
        Name                = "${var.clients_name}-${tag_specifications.value}-client"
        weka_hostgroup_type = "client"
        weka_clients_name   = var.clients_name
        user                = data.aws_caller_identity.current.user_id
      })
    }
  }
  user_data  = local.custom_data
  depends_on = [aws_placement_group.this]
}

resource "aws_instance" "this" {
  count = var.clients_number
  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  depends_on = [aws_placement_group.this]
}
