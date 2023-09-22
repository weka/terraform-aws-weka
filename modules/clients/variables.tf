variable "availability_zone" {
  type        = string
  description = "AZ in which all the resources will be deployed"
}

variable "subnet_id" {
  type        = string
  description = "Id of the subnet"
}

variable "weka_cluster_size" {
  type        = number
  description = "Number of backends in the weka cluster"
}

variable "backends_asg_name" {
  type        = string
  description = "Name of the backends autoscaling group"
}

variable "nics_numbers" {
  type        = number
  default     = 2
  description = "Number of nics to set on each client vm"
}

variable "ami_id" {
  type        = string
  description = "ami id"
  default     = null
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy"
}

variable "clients_name" {
  type        = string
  description = "The clients name."
}

variable "clients_number" {
  type        = number
  description = "The number of virtual machines to deploy."
  default     = 2
}

variable "key_pair_name" {
  type        = string
  description = "Ssh key pair name to pass to the instances."
}

variable "proxy_url" {
  type = string
}

variable "mount_clients_dpdk" {
  type        = bool
  default     = true
  description = "Install weka cluster with DPDK"
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Determines whether to assign public ip."
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

variable "instance_iam_profile_arn" {
  type        = string
  description = "Instance IAM profile ARN"
}

variable "root_volume_size" {
  type        = number
  description = "The root volume size in GB"
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name"
  default     = null
}
