variable "backends_asg_name" {
  type        = string
  description = "Name of the backends autoscaling group"
}

variable "frontend_container_cores_num" {
  type        = number
  description = "Number of frontend cores to use on instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC"
  default     = 1
}

variable "ami_id" {
  type        = string
  description = "ami id"
}

variable "protocol" {
  type        = string
  description = "Name of the protocol."
  default     = "NFS"

  validation {
    condition     = contains(["NFS", "SMB"], var.protocol)
    error_message = "Allowed values for protocol: NFS, SMB."
  }
}

variable "secondary_ips_per_nic" {
  type        = number
  description = "Number of secondary IPs per single NIC per protocol gateway virtual machine."
  default     = 2
}

variable "subnet_id" {
  type        = string
  description = "subnet id"
}

variable "gateways_number" {
  type        = number
  description = "The number of virtual machines to deploy as protocol gateways."
}

variable "gateways_name" {
  type        = string
  description = "The protocol group name."
}

variable "client_group_name" {
  type        = string
  description = "Client access group name."
  default     = "weka-cg"
}

variable "interface_group_name" {
  type        = string
  description = "Interface group name."
  default     = "weka-ig"

  validation {
    condition     = length(var.interface_group_name) <= 11
    error_message = "The interface group name should be up to 11 characters long."
  }
}

variable "assign_public_ip" {
  type        = bool
  description = "Determines whether to assign public ip."
}

variable "weka_volume_size" {
  type        = number
  description = "The disk size."
}

variable "install_weka_url" {
  type        = string
  description = "The URL of the Weka release download tar file."

  validation {
    condition     = length(var.install_weka_url) > 0
    error_message = "The URL should not be empty."
  }
}

variable "weka_token_id" {
  type        = string
  description = "Weka token id"
}

variable "instance_iam_profile_arn" {
  type        = string
  description = "Instance IAM profile ARN"
}

variable "sg_ids" {
  type        = list(string)
  default     = []
  description = "Security group ids"
}

variable "placement_group_name" {
  type        = string
  description = "Placement group name"
  default     = ""
}

variable "tags_map" {
  type        = map(string)
  default     = { "env" : "dev", "creator" : "tf" }
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value."
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy"
}

variable "key_pair_name" {
  type        = string
  description = "Ssh key pair name to pass to the instances."
}

variable "weka_cluster_size" {
  type        = number
  description = "Number of backends in the weka cluster"
}

variable "weka_password_id" {
  type        = string
  description = "Weka password id"
}

variable "proxy_url" {
  type        = string
  description = "Weka proxy url"
  default     = ""
}

variable "lb_arn_suffix" {
  type        = string
  description = "Backend Load ARN suffix"
}

variable "secret_prefix" {
  type        = string
  description = "Prefix of secrets"
}

variable "setup_protocol" {
  type        = bool
  description = "Configure protocol, default value is False"
}



variable "smbw_enabled" {
  type        = bool
  default     = false
  description = "Enable SMBW protocol."
}

variable "smb_cluster_name" {
  type        = string
  description = "The name of the SMB setup."
  default     = "Weka-SMB"

  validation {
    condition     = length(var.smb_cluster_name) > 1 && length(var.smb_cluster_name) <= 15
    error_message = "The SMB cluster name should be less than 15 characters long."
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

variable "smb_share_name" {
  type        = string
  description = "The name of the SMB share"
  default     = ""
}
