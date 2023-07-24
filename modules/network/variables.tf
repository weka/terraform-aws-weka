variable "vpc_cidr" {
  description = "CIDR block of the vpc"
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for public subnet"
  default     = ["10.0.1.0/24","10.0.2.0/24"]
}

variable "additional_subnet_cidr" {
  type        = string
  description = "Additional CIDR block for public subnet"
  default     = "10.0.3.0/24"
}

variable "private_subnets_cidr" {
  type        = list(string)
  description = "CIDR block for private subnet"
  default     = ["10.0.3.0/24"]
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

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
}

variable "additional_subnet" {
  type        = bool
  default     = true
  description = "Add additional subnet"
}