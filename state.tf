locals {
  state_bucket_name = "${var.prefix}-${var.cluster_name}-weka-deployment"
}

resource "aws_s3_bucket" "weka_deployment" {
  bucket = local.state_bucket_name
}

resource "aws_s3_object" "file_upload" {
  bucket       = aws_s3_bucket.weka_deployment.id
  key          = "state"
  content_type = "application/json"
  content      = "{\"initial_size\":${var.cluster_size}, \"desired_size\":${var.cluster_size}, \"instances\":[], \"clusterized\":false}"

  lifecycle {
    ignore_changes = all
  }
}
