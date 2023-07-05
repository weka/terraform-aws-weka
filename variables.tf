variable "region" {
  description = "Region in which the bastion host will be launched"
  type        = string
}

variable "availability_zones" {
  type        = list(string)
  description = "AZ in which all the resources will be deployed"
}

variable "subnets" {
  type        = list(string)
  description = "List of subnets ids"
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

variable "disk_size" {
  type    = number
  default = 50
}

variable "ami_image" {
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2"
  description = "ami image"
}

variable "sg_id" {
  type        = list(string)
  default     = []
  description = "Security group id"
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
  default = {
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
    condition = var.cluster_size >= 6
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

variable "obs_container_name" {
  type        = string
  default     = ""
  description = "Name of existing obs conatiner name"
}

variable "set_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "blob_obs_access_key" {
  type        = string
  description = "The access key of the existing Blob object store container."
  sensitive   = true
  default     = ""
}

variable "tiering_ssd_percent" {
  type        = number
  default     = 20
  description = "When set_obs_integration is true, this variable sets the capacity percentage of the filesystem that resides on SSD. For example, for an SSD with a total capacity of 20GB, and the tiering_ssd_percent is set to 20, the total available capacity is 100GB."
}

variable "ssh_public_key_path" {
  type    = string
  default = null
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "ssh_private_key_path" {
  type    = string
  default = null
}

variable "placement_group_name" {
  type    = string
  default = null
}

variable "apt_repo_url" {
  type        = string
  default     = ""
  description = "The URL of the apt private repository."
}

variable "install_weka_url" {
  type        = string
  description = "The URL of the Weka release download tar file."
  default     = ""
}

variable "tags_map" {
  type        = map(string)
  default     = {"env": "dev", "creator": "tf"}
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