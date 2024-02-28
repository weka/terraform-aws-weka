variable "availability_zones" {
  type        = list(string)
  description = "Required only if not specifying subnet_ids, this zone(s) will be used to create subnet that will be used by weka. Currently limited to single subnet"
  default     = []
  validation {
    condition     = length(var.availability_zones) <= 1
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

variable "nat_public_subnet_cidr" {
  type        = string
  description = "CIDR block for public subnet"
  default     = "10.0.2.0/24"
}

variable "create_nat_gateway" {
  type        = bool
  default     = false
  description = "NAT needs to be created when no public ip is assigned to the backend, to allow internet access"
}

variable "subnets_cidrs" {
  type        = list(string)
  description = "CIDR block for subnet creation, required only if not specifying subnet_ids, this block will be used to create subnet that will be used by weka. Currently limited to single"
  default     = ["10.0.1.0/24"]
  validation {
    condition     = length(var.subnets_cidrs) <= 1
    error_message = "Multiple subnets are not supported. Please provide only one subnet cidr."
  }
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "weka"
}

variable "subnet_autocreate_as_private" {
  type        = bool
  default     = false
  description = "Create private subnet using nat gateway to route traffic. The default is public network. Relevant only when subnet_ids is empty."
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public IP to all instances deployed by TF module. Includes backends, clients and protocol gateways"
}

variable "vm_username" {
  type        = string
  description = "Provided as part of output for automated use of terraform, in case of custom AMI and automated use of outputs replace this with user that should be used for ssh connection"
  default     = "ec2-user"
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy."
  default     = "i3en.2xlarge"
}

variable "ami_id" {
  type        = string
  description = "Custom AMI ID to use, by default Amazon Linux 2 is used, other distributive might work, but only Amazon Linux 2 is tested by Weka with this TF module"
  default     = null
}

variable "sg_ids" {
  type        = list(string)
  default     = []
  description = "Security group ids"
}

variable "containers_config_map" {
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
      memory   = ["62GB", "61.7GB"]
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
    condition     = alltrue([for m in flatten([for i in values(var.containers_config_map) : (flatten(i.memory))]) : tonumber(trimsuffix(m, "GB")) <= 384])
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
  default     = "4.2.8.66"
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

  validation {
    condition     = var.placement_group_name != ""
    error_message = "Placement group name may not be and empty string"
  }
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

variable "set_dedicated_fe_container" {
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
  description = "Number of hotspares to set on weka cluster. Refer to https://docs.weka.io/overview/ssd-capacity-management#hot-spare"
}

variable "instance_iam_profile_arn" {
  type        = string
  description = "IAM Role that will be used by weka backend instances, if not specified will be created automatically. If pre-created should match policy described in readme"
  default     = ""
}

variable "lambda_iam_role_arn" {
  type        = string
  description = "IAM Role that will be used by AWS Lambdas, if not specified will be created automatically. If pre-created should match policy described in readme"
  default     = ""
}

variable "additional_instance_iam_policy_statement" {
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default     = null
  description = "Additional IAM policy statement to be added to the instance IAM role."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID, required only for security group creation"
  default     = ""
}

variable "allow_ssh_cidrs" {
  type        = list(string)
  description = "Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "alb_allow_https_cidrs" {
  type        = list(string)
  description = "CIDRs to allow connecting to ALB over 443 port, by default 443 is not opened, and port 14000 used for connection, inheriting setting from  allow_weka_api_ranges "
  default     = []
}

variable "allow_weka_api_cidrs" {
  type        = list(string)
  description = "Allow connection to port 14000 on weka backends and ALB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC"
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
  description = "DynamoDB hash key name (optional configuration, will use 'Key' by default). This key will be used if dynamodb table will be created automatically, by not setting `dynamodb_table_name` param. In case `dynamodb_table_name` parameter is set, `dynamodb_hash_key_name` should match the key that should be used by us within pre-created table "
  default     = "Key"
}

variable "lambdas_version" {
  type        = string
  description = "Lambdas code version (hash)"
  default     = "28e6ea7a283aa8e692dfbf2656cc471a"
}

variable "lambdas_dist" {
  type        = string
  description = "Lambdas code dist"
  default     = "release"

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
  description = "IAM Role that will be used by cloudwatch rule(event), if not specified will be created automatically. If pre-created should match policy described in readme"
}

variable "secretmanager_use_vpc_endpoint" {
  type        = bool
  default     = true
  description = "Use of secret manager is optional, if not used secrets will be passed between lambdas over step function. If secret manager is used, all lambdas will fetch secret directly when needed."
}

variable "secretmanager_create_vpc_endpoint" {
  type        = bool
  default     = true
  description = "Enable secret manager VPC endpoint"
}

variable "secretmanager_sg_ids" {
  type        = list(string)
  default     = []
  description = "Secret manager endpoint security groups ids"
}

variable "backends_weka_volume_size" {
  type        = number
  default     = 48
  description = "The backends' default disk size."
}

########################## alb #####################################
variable "create_alb" {
  type        = bool
  default     = true
  description = "Create ALB for backend UI, and joining weka clients will use this ALB to join a cluster, allowing for better distribution of load amongst backends"
}

variable "alb_additional_subnet_id" {
  type        = string
  default     = ""
  description = "Required to specify if subnet_ids were used to specify pre-defined subnets for weka. ALB requires an additional subnet, and in the case of pre-defined networking this one also should be pre-defined"
}

variable "alb_additional_subnet_cidr_block" {
  type        = string
  description = "Additional CIDR block for public subnet"
  default     = "10.0.3.0/24"
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

variable "alb_sg_ids" {
  type        = list(string)
  default     = []
  description = "Security group ids for ALB"
}

variable "alb_route53_zone_id" {
  type        = string
  default     = ""
  description = "Route53 zone id"
}

################################################## obs variables ###################################################
variable "tiering_obs_name" {
  type        = string
  default     = ""
  description = "Name of an existing S3 bucket"
}

variable "tiering_enable_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "tiering_enable_ssd_percent" {
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
  description = "ARN of IAM Profile to use by client instance. If not specified Instance Profile will be automatically created"
  default     = ""
}

variable "client_instance_ami_id" {
  type        = string
  description = "Custom AMI ID to use, by default Amazon Linux 2 is used, other distributive might work, but only Amazon Linux 2 is tested by Weka with this TF module"
  default     = null
}

variable "client_frontend_cores" {
  type        = number
  description = "Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC"
  default     = 1
}

variable "clients_use_dpdk" {
  type        = bool
  default     = true
  description = "Mount weka clients in DPDK mode"
}

variable "client_placement_group_name" {
  type        = string
  description = "The client instances placement group name. Backend placement group can be reused. If not specified placement group will be created automatically"
  default     = null

  validation {
    condition     = var.client_placement_group_name != ""
    error_message = "Placement group name may not be and empty string"
  }
}

variable "client_weka_volume_size" {
  type        = number
  description = "The client volume size in GB"
  default     = 48
}

variable "clients_use_autoscaling_group" {
  type        = bool
  default     = false
  description = "Use autoscaling group for clients"
}

variable "clients_custom_data" {
  type        = string
  description = "Custom data to pass to the client instances"
  default     = ""
}

variable "client_arch" {
  type        = string
  default     = "x86_64"
  description = "Use arch for ami id, value can be arm64/x86_64, the default value is x86_64."
  validation {
    condition     = var.client_arch == "arm64" || var.client_arch == "x86_64"
    error_message = "Allowed client_arch values: [\"arm64\", \"x86_64\"]."
  }
}

############################################### NFS protocol gateways variables ###################################################
variable "nfs_protocol_gateway_instance_iam_profile_arn" {
  type        = string
  description = "The protocol gateway instance IAM profile ARN"
  default     = ""
}

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
  default     = "c5n.2xlarge"
}

variable "nfs_protocol_gateway_fe_cores_num" {
  type        = number
  description = "The protocol gateways' NICs number."
  default     = 1
}

variable "nfs_protocol_gateway_weka_volume_size" {
  type        = number
  default     = 48
  description = "The protocol gateways' default disk size."
}

variable "nfs_setup_protocol" {
  type        = bool
  description = "Setup protocol, default if false"
  default     = false
}

############################################### SMB protocol gateways variables ###################################################
variable "smb_protocol_gateway_instance_iam_profile_arn" {
  type        = string
  description = "The protocol gateway instance IAM profile ARN"
  default     = ""
}

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
  default     = "c5n.2xlarge"
}

variable "smb_protocol_gateway_fe_cores_num" {
  type        = number
  description = "The protocol gateways' NICs number."
  default     = 1
}

variable "smb_protocol_gateway_weka_volume_size" {
  type        = number
  default     = 48
  description = "The protocol gateways' default disk size."
}

variable "smb_setup_protocol" {
  type        = bool
  description = "Config protocol, default if false"
  default     = false
}

variable "smbw_enabled" {
  type        = bool
  default     = true
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

variable "weka_home_url" {
  type        = string
  description = "Weka Home url"
  default     = ""
}

############################### vpc endpoint services ############################
variable "vpc_endpoint_ec2_create" {
  type        = bool
  default     = false
  description = "Create Ec2 VPC endpoint"
}

variable "vpc_endpoint_s3_gateway_create" {
  type        = bool
  default     = false
  description = "Create S3 gateway VPC endpoint"
}

variable "vpc_endpoint_proxy_create" {
  type        = bool
  default     = false
  description = "creates VPC endpoint to weka-provided VPC Endpoint services that enable managed proxy to reach home.weka.io, get.weka.io, and AWS EC2/cloudwatch services”. Alternatively appropriate customer-managed proxy can be provided by proxy_url variable"
}

variable "metadata_http_tokens" {
  type        = string
  default     = "required"
  description = "Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2)"
}
