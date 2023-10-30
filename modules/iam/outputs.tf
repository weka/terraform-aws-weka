output "instance_iam_profile_arn" {
  value       = aws_iam_instance_profile.instance_profile.arn
  description = "ARN of instance profile"
}

output "lambda_iam_role_arn" {
  value       = aws_iam_role.lambda_iam_role.arn
  description = "ARN of lambda iam role"
}

output "sfn_iam_role_arn" {
  value       = aws_iam_role.sfn_iam_role.arn
  description = "ARN of SFN iam role"
}

output "event_iam_role_arn" {
  value       = aws_iam_role.event_iam_role.arn
  description = "ARN of event iam role"
}
