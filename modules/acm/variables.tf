variable "acm_domain_name" {
  type        = string
  description = "ACM domain name"
}

variable "tags_map" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign to resources"
}
