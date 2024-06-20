variable "subnet_id" {
  type        = string
  description = "Id of the subnet"
}

variable "weka_cluster_size" { # tflint-ignore: terraform_unused_declarations
  type        = number
  description = "[Deprecated] Number of backends in the weka cluster"
  default     = 0
}

variable "backends_asg_name" {
  type        = string
  description = "Name of the backends autoscaling group"
}

variable "frontend_container_cores_num" {
  type        = number
  default     = 1
  description = "Number of frontend cores to use on client instances, this number will reflect on number of NICs attached to instance, as each weka core requires dedicated NIC"
}

variable "client_instance_ami_id" {
  type        = string
  description = "Custom AMI ID to use, by default Amazon Linux 2 is used, other distributive might work, but only Amazon Linux 2 is tested by Weka with this TF module"
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
  type        = string
  default     = ""
  description = "Weka proxy url"
}

variable "clients_use_dpdk" {
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
  default     = null

  validation {
    condition     = var.placement_group_name != ""
    error_message = "Placement group name may not be and empty string"
  }
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

variable "weka_volume_size" {
  type        = number
  description = "The root volume size in GB"
  default     = 48
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name"
  default     = null
}

variable "custom_data" {
  type        = string
  description = "Custom data to pass to the instances"
  default     = ""
}

variable "use_autoscaling_group" {
  type        = bool
  description = "Use autoscaling group"
  default     = false
}

variable "arch" {
  type    = string
  default = null
}

variable "ebs_kms_key_id" {
  type        = string
  default     = ""
  description = "The ARN of the AWS Key Management Service"
}

variable "ebs_encrypted" {
  type        = bool
  default     = false
  description = "Enables EBS encryption on the volume"
}

variable "alb_listener_protocol" {
  type        = string
  description = "ALB listener protocol can be HTTP / HTTPS or empty if no ALB is used"
  default     = ""
  validation {
    condition     = var.alb_listener_protocol == "https" || var.alb_listener_protocol == "http" || var.alb_listener_protocol == ""
    error_message = "Allowed ALB protocol values: [\"http\", \"https\"]."
  }
}
