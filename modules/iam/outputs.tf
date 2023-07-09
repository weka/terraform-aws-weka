output "instance_profile_name" {
  value = aws_iam_instance_profile.instance_profile.name
}

output "lambda_iam_role_arn" {
  value = aws_iam_role.lambda_iam_role.arn
}