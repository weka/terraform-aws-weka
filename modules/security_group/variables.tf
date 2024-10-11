variable "prefix" {
  type        = string
  description = "Prefix for all resources names"
  default     = "weka"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
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

variable "cluster_name" {
  type        = string
  description = "The cluster name."
  default     = "poc"
}

variable "tags_map" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply."
}

variable "custom_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default     = []
  description = "Custom inbound rules to be added to the security group."
}
