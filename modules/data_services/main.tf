data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "amzn_ami" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.*-x86_64-gp2"]
  }
}

data "aws_ami" "provided_ami" {
  count = var.ami_id != null ? 1 : 0
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

locals {
  region    = data.aws_region.current.name
  tags_dest = ["instance", "network-interface", "volume"]

  instance_iam_profile_arn = var.instance_iam_profile_arn != "" ? var.instance_iam_profile_arn : aws_iam_instance_profile.this[0].arn

  init_script = templatefile("${path.module}/init.sh", {
    region              = local.region
    weka_log_group_name = "/wekaio/${var.data_services_name}"
    proxy_url           = var.proxy_url
    deploy_lambda_name  = var.deploy_lambda_name
  })

  placement_group_name = var.use_placement_group ? var.placement_group_name == null ? aws_placement_group.this[0].name : var.placement_group_name : null
  root_device_name     = var.ami_id != null ? data.aws_ami.provided_ami[0].root_device_name : data.aws_ami.amzn_ami[0].root_device_name
}

resource "aws_placement_group" "this" {
  count    = var.use_placement_group && var.placement_group_name == null ? 1 : 0
  name     = "${var.data_services_name}-placement-group"
  strategy = "cluster"
  tags = merge(var.tags_map, {
    CreationDate = timestamp()
  })
}

resource "aws_launch_template" "this" {
  name                                 = "${var.data_services_name}-launch-template"
  disable_api_termination              = true
  disable_api_stop                     = true
  ebs_optimized                        = true
  image_id                             = var.ami_id != null ? var.ami_id : data.aws_ami.amzn_ami[0].id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  key_name                             = var.key_pair_name
  update_default_version               = true

  block_device_mappings {
    device_name = "/dev/sdp"
    ebs {
      volume_size           = var.weka_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = var.ebs_encrypted
      kms_key_id            = var.ebs_kms_key_id
    }
  }

  block_device_mappings {
    device_name = local.root_device_name
    ebs {
      volume_size = var.root_volume_size
      encrypted   = var.ebs_encrypted
      kms_key_id  = var.ebs_kms_key_id
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
    http_tokens                 = var.metadata_http_tokens
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
    group_name        = local.placement_group_name
  }

  capacity_reservation_specification {
    capacity_reservation_target {
      capacity_reservation_id = var.capacity_reservation_id
    }
  }

  dynamic "tag_specifications" {
    for_each = local.tags_dest
    content {
      resource_type = tag_specifications.value
      tags = merge({ user = data.aws_caller_identity.current.user_id }, var.tags_map, {
        Name                = var.data_services_name
        weka_cluster_name   = var.cluster_name
        weka_hostgroup_type = "data-services"
      })
    }
  }
  user_data = base64encode(local.init_script)

  depends_on = [aws_placement_group.this]
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                  = var.data_services_name
  desired_capacity      = var.data_services_number
  max_size              = var.data_services_number
  min_size              = var.data_services_number
  vpc_zone_identifier   = [var.subnet_id]
  suspended_processes   = ["ReplaceUnhealthy"]
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }
  tag {
    key                 = var.data_services_name
    propagate_at_launch = true
    value               = var.data_services_name
  }

  dynamic "tag" {
    for_each = var.tags_map
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false # already propagated by launch template
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity, min_size, max_size]
  }
  depends_on = [aws_launch_template.this]
}
