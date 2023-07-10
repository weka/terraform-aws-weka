resource "aws_iam_role" "lambda_iam_role" {
  name               = "${var.prefix}-${var.cluster_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name   = "${var.prefix}-${var.cluster_name}-lambda-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }, {
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*Object"
        ]
        Resource = ["arn:aws:s3:::${var.state_bucket_name}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
  role       = aws_iam_role.lambda_iam_role.name
}