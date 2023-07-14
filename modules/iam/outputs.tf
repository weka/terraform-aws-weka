output "instance_iam_profile_arn" {
  value = aws_iam_instance_profile.instance_profile.arn
}

output "lambda_iam_role_arn" {
  value = aws_iam_role.lambda_iam_role.arn
}
