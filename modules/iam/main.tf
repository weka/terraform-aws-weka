locals {
  lambda_prefix = lookup(var.custom_prefix, "lambda", var.prefix)
  iam_prefix    = lookup(var.custom_prefix, "iam", var.prefix)
  ec2_prefix    = lookup(var.custom_prefix, "ec2", var.prefix)
  sfn_prefix    = lookup(var.custom_prefix, "sfn", var.prefix)
  obs_prefix    = lookup(var.custom_prefix, "obs", var.prefix)
}
