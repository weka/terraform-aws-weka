variable "ami_id" {
  type        = string
  description = "ami id"
}

variable "subnet_id" {
  type        = string
  description = "subnet id"
}

variable "data_services_number" {
  type        = number
  description = "The number of virtual machines to deploy as protocol gateways."
}

variable "cluster_name" {
  type        = string
  description = "The cluster name."
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
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply."
}

variable "instance_type" {
  type        = string
  description = "The virtual machine type (sku) to deploy"
}

variable "key_pair_name" {
  type        = string
  description = "Ssh key pair name to pass to the instances."
}

variable "proxy_url" {
  type        = string
  description = "Weka proxy url"
  default     = ""
}

variable "smb_cluster_name" {
  type        = string
  description = "The name of the SMB setup."
  default     = "Weka-SMB"

  validation {
    condition     = length(var.smb_cluster_name) > 0 && length(var.smb_cluster_name) <= 15
    error_message = "The SMB cluster name must be between 1 and 15 characters long."
  }
}

variable "deploy_lambda_name" {
  type        = string
  description = "The name of the deploy function"
}

variable "report_lambda_name" {
  type        = string
  description = "The name of the report function"
}

variable "fetch_lambda_name" {
  type        = string
  description = "The name of the fetch function"
}

variable "status_lambda_name" {
  type        = string
  description = "The name of the status function"
}

variable "secret_prefix" {
  type        = string
  description = "Secrets prefix"
}

variable "metadata_http_tokens" {
  type        = string
  default     = "required"
  description = "Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2 (IMDSv2)"
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

variable "root_volume_size" {
  type        = number
  default     = null
  description = "root disk size."
}

variable "data_services_name" {
  type        = string
  description = "The  data services name."
}

variable "iam_base_name" {
  type        = string
  description = "The prefix of the IAM role"
  default     = null
}
