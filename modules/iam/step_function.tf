resource "aws_iam_role" "sfn_iam_role" {
  name = "${local.iam_prefix}-${var.cluster_name}-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["states.amazonaws.com"]
        }
      }
    ]
  })
  tags = var.tags_map
}

resource "aws_iam_policy" "sfn_iam_policy" {
  name = "${local.iam_prefix}-${var.cluster_name}-sfn-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = ["arn:aws:lambda:*:*:function:${local.lambda_prefix}-${var.cluster_name}-*-lambda"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = ["*"]
      }
    ]
  })
  tags = var.tags_map
}

resource "aws_iam_role_policy_attachment" "sfn_policy_attachment" {
  policy_arn = aws_iam_policy.sfn_iam_policy.arn
  role       = aws_iam_role.sfn_iam_role.name
}
