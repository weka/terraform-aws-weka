variable "availability_zones" {
  type        = list(string)
  description = "AZ in which all the resources will be deployed"
  validation {
    condition     = length(var.availability_zones) == 1
    error_message = "Multiple AZs are not supported. Please provide only one AZ."
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet ids"
  default     = []
  validation {
    condition     = length(var.subnet_ids) <= 1
    error_message = "Multiple subnets are not supported. Please provide only one subnet."
  }
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "weka"
}

variable "private_network" {
  type        = bool
  default     = false
  description = "Determines whether to enable a private or public network. The default is public network. Relevant only when subnet_ids is empty."
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
}

variable "vm_username" {
  type        = string
  description = "The user name for logging in to the virtual machines."
  default     = "ec2-user"
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy."
  default     = "i3en.2xlarge"
}

variable "ami_id" {
  type        = string
  description = "ami id"
  default     = null
}

variable "sg_ids" {
  type        = list(string)
  default     = []
  description = "Security group ids"
}

variable "alb_sg_ids" {
  type        = list(string)
  default     = []
  description = "Security group ids for ALB"
}

variable "container_number_map" {
  type = map(object({
    compute  = number
    drive    = number
    frontend = number
    nvme     = number
    nics     = number
    memory   = list(string)
  }))
  description = "Maps the number of objects and memory size per machine type."
  default = {
    "i3en.2xlarge" = {
      compute  = 1
      drive    = 1
      frontend = 1
      nvme     = 2
      nics     = 4
      memory   = ["32.9GB", "32.64GB"]
    },
    "i3en.3xlarge" = {
      compute  = 1
      drive    = 1
      frontend = 1
      nvme     = 1
      nics     = 4
      memory   = ["62.GB", "61.7GB"]
    },
    "i3en.6xlarge" = {
      compute  = 5
      drive    = 1
      frontend = 1
      nvme     = 2
      nics     = 8
      memory   = ["136.5GB", "136.2GB"]
    },
    "i3en.12xlarge" = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 4
      nics     = 8
      memory   = ["310.7GB", "310.4GB"]
    },
    "i3en.24xlarge" = {
      compute  = 9
      drive    = 4
      frontend = 1
      nvme     = 8
      nics     = 15
      memory   = ["384GB", "384GB"]
    }
  }
  validation {
    condition = alltrue([for m in flatten([for i in values(var.container_number_map): (flatten(i.memory))]): tonumber(trimsuffix(m, "GB")) <= 384])
    error_message = "Compute memory can not be more then 384GB"
  }
}

variable "cluster_size" {
  type        = number
  description = "The number of virtual machines to deploy."
  default     = 6

  validation {
    condition     = var.cluster_size >= 6
    error_message = "Cluster size should be at least 6."
  }
}

variable "cluster_name" {
  type        = string
  description = "The cluster name."
  default     = "poc"
}

variable "weka_version" {
  type        = string
  description = "The Weka version to deploy."
  default     = "4.2.1"
}

variable "get_weka_io_token" {
  type        = string
  description = "The token to download the Weka release from get.weka.io."
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "Ssh public key to pass to the instances."
  default     = null
}

variable "key_pair_name" {
  type        = string
  description = "Ssh key pair name to pass to the instances."
  default     = null
}

variable "placement_group_name" {
  type    = string
  default = null
}

variable "install_weka_url" {
  type        = string
  default     = ""
  description = "The URL of the Weka release. Supports path to weka tar file or installation script."
}

variable "tags_map" {
  type        = map(string)
  default     = { "env" : "dev", "creator" : "tf" }
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value."
}

variable "add_frontend_container" {
  type        = bool
  default     = true
  description = "Create cluster with FE containers"
}

variable "weka_username" {
  type        = string
  description = "Weka cluster username"
  default     = "admin"
}

variable "protection_level" {
  type        = number
  default     = 2
  description = "Cluster data protection level."
  validation {
    condition     = var.protection_level == 2 || var.protection_level == 4
    error_message = "Allowed protection_level values: [2, 4]."
  }
}

variable "stripe_width" {
  type        = number
  default     = -1
  description = "Stripe width = cluster_size - protection_level - 1 (by default)."
  validation {
    condition     = var.stripe_width == -1 || var.stripe_width >= 3 && var.stripe_width <= 16
    error_message = "The stripe_width value can take values from 3 to 16."
  }
}

variable "hotspare" {
  type        = number
  default     = 1
  description = "Hot-spare value."
}

variable "instance_iam_profile_arn" {
  type        = string
  description = "Instance IAM profile ARN"
  default     = ""
}

variable "lambda_iam_role_arn" {
  type        = string
  description = "Lambda IAM role ARN"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC ID, required only for security group creation"
  default     = ""
}

variable "allow_ssh_ranges" {
  type        = list(string)
  description = "Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "allow_https_ranges" {
  type        = list(string)
  description = "Allow port 443, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "allow_weka_api_ranges" {
  type        = list(string)
  description = "Allow port 14000, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "proxy_url" {
  type        = string
  description = "Weka proxy url"
  default     = ""
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table name, if not supplied a new table will be created"
  default     = ""
}

variable "dynamodb_hash_key_name" {
  type        = string
  description = "DynamoDB hash key name (optional configuration, will use 'Key' by default)"
  default     = "Key"
}

variable "lambdas_version" {
  type        = string
  description = "Lambdas code version (hash)"
  default     = "3aec35033eef8d8e7805ef952c74a7cf"
}

variable "lambdas_dist" {
  type        = string
  description = "Lambdas code dist"
  default     = "dev"

  validation {
    condition     = contains(["dev", "release"], var.lambdas_dist)
    error_message = "Valid value is one of the following: dev, release."
  }
}

variable "sfn_iam_role_arn" {
  type        = string
  default     = ""
  description = "Step function iam role arn"
}

variable "event_iam_role_arn" {
  type        = string
  default     = ""
  description = "Event iam role arn"
}

variable "use_secretmanager_endpoint" {
  type        = bool
  default     = true
  description = "Use secret manager endpoint"
}

variable "create_secretmanager_endpoint" {
  type        = bool
  default     = true
  description = "Enable secret manager endpoint on vpc"
}

variable "secretmanager_endpoint_sg_ids" {
  type        = list(string)
  default     = []
  description = "Secret manager endpoint security groups ids"
}

variable "create_alb" {
  type        = bool
  default     = true
  description = "Create ALB"
}

variable "additional_alb_subnet" {
  type        = string
  default     = ""
  description = "Additional subnet for ALB"
}

variable "alb_cert_arn" {
  type        = string
  default     = null
  description = "HTTPS certificate ARN for ALB"
}

variable "alb_alias_name" {
  type        = string
  default     = ""
  description = "Set ALB alias name"
}

variable "route53_zone_id" {
  type        = string
  default     = ""
  description = "Route53 zone id"
}

################################################## obs variables ###################################################
variable "obs_name" {
  type        = string
  default     = ""
  description = "Name of existing obs storage account"
}

variable "set_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "tiering_ssd_percent" {
  type        = number
  default     = 20
  description = "When set_obs_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering_ssd_percent is set to 20, the total available capacity is 100GB."
}

################################################## clients variables ###################################################
variable "clients_number" {
  type        = number
  description = "The number of client instances to deploy"
  default     = 0
}

variable "client_instance_type" {
  type        = string
  description = "The client instance type (sku) to deploy"
  default     = "c5.2xlarge"
}

variable "client_instance_iam_profile_arn" {
  type        = string
  description = "The client instance IAM profile ARN"
  default     = ""
}

variable "client_instance_ami_id" {
  type        = string
  description = "The client instance AMI ID"
  default     = null
}

variable "client_nics_num" {
  type        = string
  description = "The client NICs number"
  default     = 2
}

variable "mount_clients_dpdk" {
  type        = bool
  default     = true
  description = "Mount weka clients in DPDK mode"
}

variable "client_placement_group_name" {
  type        = string
  description = "The client instances placement group name"
  default     = ""
}

variable "client_root_volume_size" {
  type        = number
  description = "The client root volume size in GB"
  default     = 50
}

############################################### protocol gateways variables ###################################################
variable "protocol_gateway_instance_iam_profile_arn" {
  type        = string
  description = "The protocol gateway instance IAM profile ARN"
  default     = ""
}

############################################### NFS protocol gateways variables ###################################################
variable "nfs_protocol_gateways_number" {
  type        = number
  description = "The number of protocol gateway virtual machines to deploy."
  default     = 0
}

variable "nfs_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 3
}

variable "nfs_protocol_gateway_instance_type" {
  type        = string
  description = "The protocol gateways' virtual machine type (sku) to deploy."
  default     = "c5.2xlarge"
}

variable "nfs_protocol_gateway_nics_num" {
  type        = string
  description = "The protocol gateways' NICs number."
  default     = 2
}

variable "nfs_protocol_gateway_disk_size" {
  type        = number
  default     = 48
  description = "The protocol gateways' default disk size."
}

variable "nfs_protocol_gateway_frontend_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on single protocol gateway machine."
}

variable "nfs_setup_protocol" {
  type        = bool
  description = "Setup protocol, default if false"
  default     = false
}

############################################### SMB protocol gateways variables ###################################################
variable "smb_protocol_gateways_number" {
  type        = number
  description = "The number of protocol gateway virtual machines to deploy."
  default     = 0
}

variable "smb_protocol_gateway_secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 3
}

variable "smb_protocol_gateway_instance_type" {
  type        = string
  description = "The protocol gateways' virtual machine type (sku) to deploy."
  default     = "c5.2xlarge"
}

variable "smb_protocol_gateway_nics_num" {
  type        = string
  description = "The protocol gateways' NICs number."
  default     = 2
}

variable "smb_protocol_gateway_disk_size" {
  type        = number
  default     = 48
  description = "The protocol gateways' default disk size."
}

variable "smb_protocol_gateway_frontend_cores_num" {
  type        = number
  default     = 1
  description = "The number of frontend cores on single protocol gateway machine."
}

variable "smb_setup_protocol" {
  type        = bool
  description = "Config protocol, default if false"
  default     = false
}

variable "smbw_enabled" {
  type        = bool
  default     = false
  description = "Enable SMBW protocol. This option should be provided before cluster is created to leave extra capacity for SMBW setup."
}

variable "smb_cluster_name" {
  type        = string
  description = "The name of the SMB setup."
  default     = "Weka-SMB"

  validation {
    condition     = length(var.smb_cluster_name) > 0
    error_message = "The SMB cluster name cannot be empty."
  }
}

variable "smb_domain_name" {
  type        = string
  description = "The domain to join the SMB cluster to."
  default     = ""
}

variable "smb_domain_netbios_name" {
  type        = string
  description = "The domain NetBIOS name of the SMB cluster."
  default     = ""
}

variable "smb_dns_ip_address" {
  type        = string
  description = "DNS IP address"
  default     = ""
}

variable "smb_share_name" {
  type        = string
  description = "The name of the SMB share"
  default     = "default"
}

variable "weka_home_url" {
  type        = string
  description = "Weka Home url"
  default     = ""
}

############################### vpc endpoint services ############################
variable "create_ec2_endpoint" {
  type        = bool
  default     = false
  description = "Create Ec2 endpoint"
}

variable "create_s3_gateway_endpoint" {
  type        = bool
  default     = false
  description = "Create S3 gateway endpoint"
}

variable "create_proxy_endpoint" {
  type        = bool
  default     = false
  description = "Create proxy endpoint"
}
