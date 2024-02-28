variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the vpc"
  default     = "10.0.0.0/16"
}

variable "subnets_cidrs" {
  type        = list(string)
  description = "CIDR block for subnet"
  default     = ["10.0.1.0/24"]
}

variable "alb_additional_subnet_cidr_block" {
  type        = string
  description = "Additional CIDR block for public subnet"
  default     = "10.0.3.0/24"
}

variable "nat_public_subnet_cidr" {
  type        = string
  description = "CIDR block for public subnet"
  default     = "10.0.2.0/24"
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

variable "subnet_autocreate_as_private" {
  type        = bool
  default     = false
  description = "Determines whether to enable a private or public network. The default is public network."
}

variable "additional_subnet" {
  type        = bool
  default     = true
  description = "Add additional subnet"
}

variable "create_nat_gateway" {
  type        = bool
  default     = false
  description = "NAT needs to be created when no public ip is assigned to the backend, to allow internet access"
}
