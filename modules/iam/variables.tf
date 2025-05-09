variable "prefix" {
  type        = string
  description = "Prefix for all resources names"
  default     = "weka"
}

variable "custom_prefix" {
  type        = map(string)
  description = "Custom prefix for resources. The supported keys are: lb, db, kms, cloudwatch, sfn, lambda, secrets, ec2, iam, obs"
  default     = {}
  validation {
    condition     = alltrue([for k, v in var.custom_prefix : contains(["lb", "db", "kms", "cloudwatch", "sfn", "lambda", "secrets", "ec2", "iam", "obs"], k)])
    error_message = "Custom prefix keys should be of the following: [\"lb\", \"db\", \"kms\", \"cloudwatch\", \"sfn\", \"lambda\", \"secrets\", \"ec2\", \"iam\", \"obs\"]."
  }
}


variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "tiering_enable_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "tiering_obs_name" {
  type        = string
  description = "Obs name"
}

variable "state_table_name" {
  type        = string
  description = "State DynamoDB table name"
}

variable "secret_prefix" {
  type        = string
  description = "Secrets prefix"
}

variable "additional_iam_policy_statement" {
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default     = null
  description = "Additional IAM policy statement to be added to the instance IAM role."

  validation {
    condition     = var.additional_iam_policy_statement != null ? length(var.additional_iam_policy_statement) > 0 : true
    error_message = "Additional IAM policy statement must be a non-empty list (if provided)."
  }
}

variable "tags_map" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply."
}
