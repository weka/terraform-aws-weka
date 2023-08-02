variable "prefix" {
  type        = string
  description = "Prefix for all resources names"
  default     = "weka"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "set_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "obs_name" {
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
