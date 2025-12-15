locals {
  # Merge user-provided tags with required aws-apn-id tag
  tags = merge(
    var.tags_map,
    {
      aws-apn-id = "pc:epkj0ftddjwa38m3oq9umjjlm"
    }
  )
  lambda_prefix = lookup(var.custom_prefix, "lambda", var.prefix)
  iam_prefix    = lookup(var.custom_prefix, "iam", var.prefix)
  ec2_prefix    = lookup(var.custom_prefix, "ec2", var.prefix)
  sfn_prefix    = lookup(var.custom_prefix, "sfn", var.prefix)
  obs_prefix    = lookup(var.custom_prefix, "obs", var.prefix)
}
