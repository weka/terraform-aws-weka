# IAM role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "AutoDestroyLambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda to allow EC2 actions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "AutoDestroyLambdaPolicy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "ec2:TerminateInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
