locals {
  ec2_prefix       = lookup(var.custom_prefix, "ec2", var.prefix)
  ssh_path         = "/tmp/${local.ec2_prefix}-${var.cluster_name}"
  nics             = var.install_cluster_dpdk ? var.containers_config_map[var.instance_type].nics : 1
  public_ssh_key   = var.enable_key_pair && var.ssh_public_key == null ? tls_private_key.key[0].public_key_openssh : var.ssh_public_key
  tags_dest        = ["instance", "network-interface", "volume"]
  weka_volume_size = var.backends_weka_volume_size + 10 * (local.nics - 1)
  user_data = templatefile("${path.module}/user_data.sh", {
    region              = local.region
    proxy               = var.proxy_url
    subnet_id           = local.subnet_ids[0]
    groups              = join(" ", local.sg_ids)
    nics_num            = local.nics
    deploy_lambda_name  = aws_lambda_function.deploy_lambda.function_name
    weka_log_group_name = "/wekaio/${local.ec2_prefix}-${var.cluster_name}"
    custom_data         = var.custom_data
  })
  backends_placement_group_name = var.use_placement_group ? var.placement_group_name == null ? aws_placement_group.placement_group[0].name : var.placement_group_name : null
  create_ebs_kms_key            = var.ebs_encrypted && var.ebs_kms_key_id == null
  ebs_kms_key_id                = local.create_ebs_kms_key ? aws_kms_key.kms_key[0].arn : var.ebs_kms_key_id
  iam_prefix                    = lookup(var.custom_prefix, "iam", var.prefix)
  root_device_name              = var.ami_id != null ? data.aws_ami.provided_ami[0].root_device_name : data.aws_ami.amzn_ami[0].root_device_name
}

data "aws_caller_identity" "current" {}

data "aws_subnet" "this" {
  count      = length(local.subnet_ids)
  id         = local.subnet_ids[count.index]
  depends_on = [module.network]
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

# =============== ssh key ===================
resource "tls_private_key" "key" {
  count     = var.enable_key_pair && var.ssh_public_key == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  count      = var.enable_key_pair && var.key_pair_name == null ? 1 : 0
  key_name   = "${local.ec2_prefix}-${var.cluster_name}-ssh-key"
  public_key = local.public_ssh_key
  tags       = var.tags_map
}

resource "local_file" "public_key" {
  count           = var.enable_key_pair && var.key_pair_name == null && var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.key[count.index].public_key_openssh
  filename        = "${local.ssh_path}-public-key.pub"
  file_permission = "0600"
}

resource "local_file" "private_key" {
  count           = var.enable_key_pair && var.key_pair_name == null && var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.key[count.index].private_key_pem
  filename        = "${local.ssh_path}-private-key.pem"
  file_permission = "0600"
}

resource "aws_placement_group" "placement_group" {
  count    = var.use_placement_group && var.placement_group_name == null ? 1 : 0
  name     = "${local.ec2_prefix}-${var.cluster_name}-placement-group"
  strategy = "cluster"
  tags = merge(var.tags_map, {
    CreationDate = timestamp()
  })
  depends_on = [module.network]
}

resource "aws_kms_key" "kms_key" {
  count                   = local.create_ebs_kms_key ? 1 : 0
  enable_key_rotation     = true
  deletion_window_in_days = 20
  is_enabled              = true
  tags = merge(var.tags_map, {
    Name = "${local.kms_prefix}-${var.cluster_name}"
  })
}

resource "aws_kms_alias" "kms_alias" {
  count         = local.create_ebs_kms_key ? 1 : 0
  name          = "alias/${local.kms_prefix}-${var.cluster_name}"
  target_key_id = aws_kms_key.kms_key[0].key_id
  depends_on    = [aws_kms_key.kms_key]
}

resource "aws_kms_key_policy" "kms_key_policy" {
  count  = local.create_ebs_kms_key ? 1 : 0
  key_id = aws_kms_key.kms_key[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        Sid    = "Allow service-linked role use of the customer managed key",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow service-linked role use of the customer managed key",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"

        },
        Action = [
          "kms:CreateGrant"
        ],
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : true
          }
        }
      }
    ]
  })
  depends_on = [aws_kms_key.kms_key]
}


resource "aws_launch_template" "launch_template" {
  name_prefix                          = "${local.ec2_prefix}-${var.cluster_name}-backend"
  disable_api_termination              = true
  disable_api_stop                     = true
  ebs_optimized                        = true
  image_id                             = var.ami_id != null ? var.ami_id : data.aws_ami.amzn_ami[0].id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  key_name                             = var.enable_key_pair ? var.key_pair_name != null ? var.key_pair_name : aws_key_pair.generated_key[0].key_name : null
  update_default_version               = true
  block_device_mappings {
    device_name = "/dev/sdp"
    ebs {
      volume_size           = local.weka_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      kms_key_id            = local.ebs_kms_key_id
      encrypted             = var.ebs_encrypted
    }
  }
  block_device_mappings {
    device_name = local.root_device_name
    ebs {
      volume_size = var.backends_root_volume_size
      encrypted   = var.ebs_encrypted
      kms_key_id  = local.ebs_kms_key_id
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
    associate_public_ip_address = local.assign_public_ip
    delete_on_termination       = true
    device_index                = 0
    security_groups             = local.sg_ids
    subnet_id                   = local.subnet_ids[0]
  }

  placement {
    availability_zone = data.aws_subnet.this[0].availability_zone
    group_name        = local.backends_placement_group_name
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
        Name                = "${local.ec2_prefix}-${var.cluster_name}-${tag_specifications.value}-backend"
        weka_cluster_name   = var.cluster_name
        weka_hostgroup_type = "backend"
      })
    }
  }
  user_data  = base64encode(local.user_data)
  depends_on = [aws_placement_group.placement_group, aws_kms_key.kms_key]
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name = "${local.ec2_prefix}-${var.cluster_name}-autoscaling-group"
  #availability_zones  = [ for z in var.availability_zones: format("%s%s", local.region,z) ]
  desired_capacity      = var.cluster_size
  max_size              = var.cluster_size * 7
  min_size              = var.cluster_size
  vpc_zone_identifier   = [local.subnet_ids[0]]
  suspended_processes   = ["ReplaceUnhealthy"]
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }
  tag {
    key                 = "${local.ec2_prefix}-${var.cluster_name}-asg"
    propagate_at_launch = true
    value               = var.cluster_name
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
  depends_on = [aws_launch_template.launch_template, aws_placement_group.placement_group]
}
