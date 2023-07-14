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
  description = "Determines whether to enable a private or public network. The default is public network."
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

variable "sg_id" {
  type        = list(string)
  default     = []
  description = "Security group ids"
}

variable "container_number_map" {
  type = map(object({
    compute  = number
    drive    = number
    frontend = number
    nvme     = number
    nics     = number
    memory   = string
  }))
  description = "Maps the number of objects and memory size per machine type."
  default     = {
    "i3en.2xlarge" = {
      compute  = 1
      drive    = 1
      frontend = 1
      nvme     = 1
      nics     = 4
      memory   = "31796436575B"
    },
    "i3.2xlarge" = {
      compute  = 1
      drive    = 1
      frontend = 1
      nvme     = 1
      nics     = 4
      memory   = "31796436575B"
    },
    "i3en.3xlarge" = {
      compute  = 2
      drive    = 1
      frontend = 1
      nvme     = 2
      nics     = 4
      memory   = "55955545954B"
    },
    "i3.3xlarge" = {
      compute  = 2
      drive    = 1
      frontend = 1
      nvme     = 2
      nics     = 4
      memory   = "55955545954B"
    },
    "i3en.6xlarge" = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 4
      nics     = 8
      memory   = "130433516148B"
    },
    "i3.6xlarge" = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 4
      nics     = 8
      memory   = "130433516148B"
    },
    "i3en.12xlarge" = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 6
      nics     = 8
      memory   = "312901542392B"
    },
    "i3.12xlarge" = {
      compute  = 4
      drive    = 2
      frontend = 1
      nvme     = 6
      nics     = 8
      memory   = "312901542392B"
    },
    "i3en.24xlarge" = {
      compute  = 9
      drive    = 4
      frontend = 1
      nvme     = 8
      nics     = 15
      memory   = "602459825769B"
    },
    "i3.24xlarge" = {
      compute  = 9
      drive    = 4
      frontend = 1
      nvme     = 8
      nics     = 15
      memory   = "602459825769B"
    }
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
  default     = "4.2.0.142"
}

variable "get_weka_io_token" {
  type        = string
  description = "The token to download the Weka release from get.weka.io."
  sensitive   = true
}

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

variable "install_cluster_dpdk" {
  type        = bool
  default     = true
  description = "Install weka cluster with DPDK"
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

variable "instance_profile_name" {
  type        = string
  description = "Instance profile name"
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
  description = "Allow ssh from ips list to weka vms"
  default     = []
}

variable "proxy_url" {
  type        = string
  description = "Weka home proxy url"
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
  type = string
  description = "Lambdas code version (hash)"
  default = "0e443ba2223cbe54dabfad362b298d5e"
}

variable "lambdas_dist" {
  type = string
  description = "Lambdas code dist"
  default = "dev"

  validation {
    condition = contains(["dev", "release"], var.lambdas_dist)
    error_message = "Valid value is one of the following: dev, release."
  }
}