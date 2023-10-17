variable "vpc_id" {
  type        = string
  description = "VPC ID, required only for security group creation"
}

variable "create_ec2_endpoint" {
  type        = bool
  description = "Create ec2 endpoint"
}

variable "create_proxy_endpoint" {
  type        = bool
  description = "Create proxy endpoint"
}

variable "create_s3_gateway_endpoint" {
  type        = bool
  description = "Create s3 gateway endpoint"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet ids"
}

variable "sg_ids" {
  type        = list(string)
  description = "List of sg ids"
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
}

variable "region_map" {
  type        = map(string)
  description = "Name of region"
  default = {
    "ap-northeast-1" = "com.amazonaws.vpce.ap-northeast-1.vpce-svc-0e8a99999813c71e0",
    "ap-northeast-2" = "com.amazonaws.vpce.ap-northeast-2.vpce-svc-093e0eeec8b7c6c4c",
    "ap-northeast-3" = "com.amazonaws.vpce.ap-northeast-3.vpce-svc-09e56cde55ad96a63",
    "ap-south-1"     = "com.amazonaws.vpce.ap-south-1.vpce-svc-09213c43e5711950a",
    "ap-southeast-1" = "com.amazonaws.vpce.ap-southeast-1.vpce-svc-0816aac78693475d6",
    "ap-southeast-2" = "com.amazonaws.vpce.ap-southeast-2.vpce-svc-0a473ac647eb853bc",
    "ca-central-1"   = "com.amazonaws.vpce.ca-central-1.vpce-svc-0f3a4b3b0d8c87a7b",
    "eu-central-1"   = "com.amazonaws.vpce.eu-central-1.vpce-svc-0a7f7dd92c316e3fc",
    "eu-north-1"     = "com.amazonaws.vpce.eu-north-1.vpce-svc-006e6faae3f3be641",
    "eu-west-1"      = "com.amazonaws.vpce.eu-west-1.vpce-svc-0f7e742f1fa52d2f7",
    "eu-west-2"      = "com.amazonaws.vpce.eu-west-2.vpce-svc-0ef99d828da2992a6",
    "me-south-1"     = "com.amazonaws.vpce.me-south-1.vpce-svc-06d65d1ac36af2e46",
    "sa-east-1"      = "com.amazonaws.vpce.sa-east-1.vpce-svc-031d8ee7326794e03",
    "us-east-1"      = "com.amazonaws.vpce.us-east-1.vpce-svc-0a99896cec98e7f63",
    "us-east-2"      = "com.amazonaws.vpce.us-east-2.vpce-svc-009318e9319949b54",
    "us-west-1"      = "com.amazonaws.vpce.us-west-1.vpce-svc-0d8adfe18973b86d8",
    "us-west-2"      = "com.amazonaws.vpce.us-west-2.vpce-svc-05e512cfd7a03b097"
  }
}

variable "region" {
  type        = string
  description = "Region name"
}