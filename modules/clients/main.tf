data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "selected" {
  count       = var.client_instance_ami_id == null ? 1 : 0
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
    nics_num            = var.frontend_container_cores_num + 1
    subnet_id           = var.subnet_id
    region              = local.region
    groups              = join(" ", var.sg_ids)
    weka_log_group_name = "/wekaio/clients/${var.clients_name}"
  })

  mount_wekafs_script = templatefile("${path.module}/mount_wekafs.sh", {
    frontend_container_cores_num = var.frontend_container_cores_num
    weka_cluster_size            = var.weka_cluster_size
    backends_asg_name            = var.backends_asg_name
    clients_use_dpdk             = var.clients_use_dpdk
    region                       = local.region
    alb_dns_name                 = var.alb_dns_name != null ? var.alb_dns_name : ""
  })

  custom_data_parts = [local.preparation_script, local.mount_wekafs_script, "${var.custom_data}\n"]
  custom_data       = base64encode(join("\n", local.custom_data_parts))
}

resource "aws_placement_group" "this" {
  count    = var.placement_group_name == null ? 1 : 0
  name     = "${var.clients_name}-placement-group"
  strategy = "cluster"
}

resource "aws_launch_template" "this" {
  name                                 = "${var.clients_name}-launch-template"
  disable_api_termination              = false
  ebs_optimized                        = true
  image_id                             = var.client_instance_ami_id != null ? var.client_instance_ami_id : data.aws_ami.selected[0].id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  key_name                             = var.key_pair_name
  update_default_version               = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.weka_volume_size
      volume_type           = "gp3"
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
    availability_zone = data.aws_subnet.selected.availability_zone
    group_name        = var.placement_group_name == null ? aws_placement_group.this[0].name : var.placement_group_name
  }

  dynamic "tag_specifications" {
    for_each = local.tags_dest
    content {
      resource_type = tag_specifications.value
      tags = merge(var.tags_map, {
        Name                = var.clients_name
        weka_hostgroup_type = "client"
        user                = data.aws_caller_identity.current.user_id
      })
    }
  }
  user_data = local.custom_data
  lifecycle {
    precondition {
      condition     = var.alb_dns_name == null ? var.weka_cluster_size > 0 : true
      error_message = "Please povide weka_cluster size in case of not using ALB"
    }
  }
  depends_on = [aws_placement_group.this]
}

resource "aws_instance" "this" {
  count = var.use_autoscaling_group ? 0 : var.clients_number
  launch_template {
    id = aws_launch_template.this.id
  }

  lifecycle {
    ignore_changes = [tags, launch_template, user_data]
  }

  depends_on = [aws_placement_group.this]
}

resource "aws_autoscaling_group" "autoscaling_group" {
  count = var.use_autoscaling_group ? 1 : 0
  name  = "${var.clients_name}-asg"
  #availability_zones  = [ for z in var.availability_zones: format("%s%s", local.region,z) ]
  desired_capacity      = var.clients_number
  max_size              = var.clients_number
  min_size              = var.clients_number
  vpc_zone_identifier   = [var.subnet_id]
  suspended_processes   = ["ReplaceUnhealthy"]
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  lifecycle {
    ignore_changes = [desired_capacity, min_size, max_size]
  }
  depends_on = [aws_launch_template.this]
}
