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

  init_script = templatefile("${path.module}/init.sh", {
    nics_num            = var.frontend_container_cores_num + 1
    subnet_id           = var.subnet_id
    region              = local.region
    groups              = join(" ", var.sg_ids)
    weka_log_group_name = "/wekaio/${var.gateways_name}"
    weka_token_id       = var.weka_token_id
    proxy_url           = var.proxy_url
    install_weka_url    = var.install_weka_url
  })

  deploy_script = templatefile("${path.module}/deploy_protocol_gateways.sh", {
    subnet_prefixes              = data.aws_subnet.selected.cidr_block
    frontend_container_cores_num = var.frontend_container_cores_num
    secondary_ips_per_nic        = var.secondary_ips_per_nic
    weka_cluster_size            = var.weka_cluster_size
    backends_asg_name            = var.backends_asg_name
    region                       = local.region
    weka_password_id             = var.weka_password_id
    lb_arn_suffix                = var.lb_arn_suffix
  })

  setup_nfs_protocol_script = templatefile("${path.module}/setup_nfs.sh", {
    gateways_name        = var.gateways_name
    interface_group_name = var.interface_group_name
    client_group_name    = var.client_group_name
  })

  setup_smb_protocol_script = templatefile("${path.module}/setup_smb.sh", {
    cluster_name                 = var.smb_cluster_name
    domain_name                  = var.smb_domain_name
    domain_netbios_name          = var.smb_domain_netbios_name
    smbw_enabled                 = var.smbw_enabled
    dns_ip                       = var.smb_dns_ip_address
    gateways_number              = var.gateways_number
    gateways_name                = var.gateways_name
    frontend_container_cores_num = var.frontend_container_cores_num
    share_name                   = var.smb_share_name
    region                       = local.region

  })

  protocol_script = var.protocol == "NFS" ? local.setup_nfs_protocol_script : local.setup_smb_protocol_script

  setup_protocol_script = var.setup_protocol ? local.protocol_script : ""

  custom_data_parts = [
    local.init_script, local.deploy_script, local.setup_protocol_script
  ]
  custom_data = join("\n", local.custom_data_parts)
}

resource "aws_placement_group" "this" {
  count    = var.placement_group_name == null ? 1 : 0
  name     = "${var.gateways_name}-placement-group"
  strategy = "cluster"
}

resource "aws_launch_template" "this" {
  name                                 = "${var.gateways_name}-launch-template"
  disable_api_termination              = false
  ebs_optimized                        = true
  image_id                             = var.ami_id != null ? var.ami_id : data.aws_ami.selected[0].id
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
    ipv4_address_count          = var.secondary_ips_per_nic
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
        Name                = var.gateways_name
        weka_hostgroup_type = "gateways-protocol"
        user                = data.aws_caller_identity.current.user_id
        protocol            = var.protocol
      })
    }
  }
  user_data  = base64encode(local.custom_data)
  depends_on = [aws_placement_group.this]
}

resource "aws_instance" "this" {
  count = var.gateways_number
  launch_template {
    id = aws_launch_template.this.id
  }

  lifecycle {
    ignore_changes = [tags, launch_template, user_data]
    precondition {
      condition     = var.protocol == "NFS" ? var.gateways_number >= 1 : var.gateways_number >= 3 && var.gateways_number <= 8
      error_message = "The amount of protocol gateways should be at least 1 for NFS and at least 3 and at most 8 for SMB."
    }
    precondition {
      condition     = var.protocol == "SMB" && var.setup_protocol ? var.smb_domain_name != "" : true
      error_message = "The SMB domain name should be set when deploying SMB protocol gateways."
    }
    precondition {
      condition     = var.protocol == "SMB" ? var.secondary_ips_per_nic <= 3 : true
      error_message = "The number of secondary IPs per single NIC per protocol gateway virtual machine must be at most 3 for SMB."
    }
  }

  depends_on = [aws_placement_group.this, aws_iam_instance_profile.this, aws_iam_role.this]
}
