variable "prefix" {
  type = string
  description = "Prefix for all resources"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z\\-\\_0-9]{1,64}$", var.prefix))
    error_message = "Prefix name must start with letter, only contain letters, numbers, dashes, or underscores."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the vpc"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets_cidr" {
  type        = list(string)
  description = "CIDR block for Subnet"
}

variable "region" {
  description = "Region in which the bastion host will be launched"
  type        = string
}

variable "availability_zones" {
  type        = list(string)
  description = "AZ in which all the resources will be deployed"
}

variable "get_weka_io_token" {
  type = string
  sensitive = true
  description = "Get get.weka.io token for downloading weka"
  default = ""
}

variable "cluster_name" {
  type = string
  description = "Cluster name"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z\\-\\_0-9]{1,64}$", var.cluster_name))
    error_message = "Cluster name must start with letter, only contain letters, numbers, dashes, or underscores."
  }
}

variable "instance_type" {
  type = string
  description = "The SKU which should be used for this virtual machine"
}

variable "set_obs_integration" {
  type = bool
  description = "Should be true to enable OBS integration with weka cluster"
}

variable "tiering_ssd_percent" {
  type = number
  description = "When OBS integration set to true , this parameter sets how much of the filesystem capacity should reside on SSD. For example, if this parameter is 20 and the total available SSD capacity is 20GB, the total capacity would be 100GB"
}

variable "cluster_size" {
  type = number
  description = "Weka cluster size"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "allow_ssh_from_ips" {
  type        = list(string)
  description = "Allow ssh from ips list to weka vms"
}