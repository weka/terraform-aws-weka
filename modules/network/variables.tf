variable "vpc_cidr" {
  description = "CIDR block of the vpc"
  default     = "10.0.0.0/16"
}

variable "subnets_cidr" {
  type        = list(string)
  description = "CIDR block for Subnet"
  default     = ["10.0.1.0/24"]
}

variable "region" {
  description = "Region in which the bastion host will be launched"
  type        = string
}

variable "availability_zones" {
  type        = list(string)
  description = "AZ in which all the resources will be deployed"
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
