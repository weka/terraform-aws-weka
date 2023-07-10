variable "prefix" {
  type        = string
  description = "Prefix for all resources names"
  default     = "weka"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "obs_name" {
  type        = string
  description = "Obs name"
}

variable "state_table_name" {
  type        = string
  description = "State DynamoDB table name"
}
