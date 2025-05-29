variable "name" {
  type        = string
  description = "KMS key name."
}

variable "tags_map" {
  type        = map(string)
  default     = {}
  description = "A map of tags to assign the same metadata to all resources in the environment. Format: key:value. Note: Manually tagged resources will be overridden by Terraform apply. Example: if we want to have 2 tags, one with key \"Key1\" and value \"Val1\" and another one with key \"Key2\" and value \"Val2\" , we should set: tags_map = { \"Key1\" = \"Val1\", \"Key2\" = \"Val2\" }"
}

variable "principal" {
  type        = string
  description = "The principal that will be granted permissions to use the KMS key. This is typically an IAM role or user ARN."
}
