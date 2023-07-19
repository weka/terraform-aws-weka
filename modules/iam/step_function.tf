resource "aws_iam_role" "sfn_iam_role" {
  name               = "${var.prefix}-${var.cluster_name}-sfn-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = ["states.amazonaws.com"]
        }
      }
    ]
  })
}

resource "aws_iam_policy" "sfn_iam_policy" {
  name   = "${var.prefix}-${var.cluster_name}-sfn-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = ["arn:aws:lambda:*:*:function:${var.prefix}-${var.cluster_name}-*-lambda"]
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
}

resource "aws_iam_role_policy_attachment" "sfn_policy_attachment" {
  policy_arn = aws_iam_policy.sfn_iam_policy.arn
  role       = aws_iam_role.sfn_iam_role.name
}
