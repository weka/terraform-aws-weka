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
  description = "The default AMI ID is set to Amazon Linux 2. For the list of all supported Weka Client OSs please refer to: https://docs.weka.io/planning-and-installation/prerequisites-and-compatibility#operating-system"
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
  default     = {}
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply."
}

variable "instance_iam_profile_arn" {
  type        = string
  description = "Instance IAM profile ARN"
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name"
  default     = null
}

variable "custom_data" {
  type        = string
  description = "Custom data to pass to the instances. Deprecated, use `custom_data_post_mount` instead."
  default     = ""
}

variable "custom_data_pre_mount" {
  type        = string
  description = "Custom data to pass to the instances, will run before weka agent install and mount."
  default     = ""
}

variable "custom_data_post_mount" {
  type        = string
  description = "Custom data to pass to the instances, will run after weka agent install and mount."
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
  default     = true
  description = "Enables EBS encryption on the volume"
}

variable "use_placement_group" {
  type        = bool
  default     = true
  description = "Use cluster placement group for clients. Note: If not using a cluster placement group, the instances will most likely be spread out across the underlying AWS infrastructure, resulting in not getting the maximum performance from the WEKA cluster"
}

variable "capacity_reservation_id" {
  type        = string
  default     = null
  description = "The ID of the capacity reservation in which to run the clients"
}

variable "metadata_http_tokens" {
  type        = string
  default     = "required"
  description = "Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2)"
}

variable "iam_base_name" {
  type        = string
  description = "The prefix of the IAM role"
  default     = "weka"
}

variable "root_volume_size" {
  type        = number
  default     = 48
  description = "root disk size."
}

variable "cert_pem" {
  type        = string
  description = "Certificate PEM to use for the ALB when using self-signed certificate."
  default     = null
}
