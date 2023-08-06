variable "prefix" {
  type        = string
  description = "Prefix for all resources names"
  default     = "weka"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "allow_ssh_ranges" {
  type        = list(string)
  description = "Allow ssh from ips list to weka vms"
  default     = []
}
