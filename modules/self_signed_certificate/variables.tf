variable "common_name" {
  type        = string
  description = "Common name for the certificate (e.g., example.com)"
}

variable "organization" {
  type        = string
  description = "Organization name"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the ACM certificate"
  default     = {}
}
