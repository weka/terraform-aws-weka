variable "prefix" {
  type        = string
  description = "Prefix for all resources names"
  default     = "weka"
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
