resource "aws_iam_role" "lambda_iam_role" {
  name = "${local.iam_prefix}-${var.cluster_name}-lambda-role"
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
  tags = var.tags_map
}

resource "aws_iam_policy" "lambda_iam_policy" {
  name = "${local.iam_prefix}-${var.cluster_name}-lambda-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:log-group:/aws/lambda/${local.lambda_prefix}-${var.cluster_name}*:*"]
        }, {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:ModifyInstanceAttribute",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:CreateTags",
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
        ]
        Resource = ["arn:aws:dynamodb:*:*:table/${var.state_table_name}"]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue"
        ]
        Resource = ["arn:aws:secretsmanager:*:*:secret:${var.secret_prefix}*"]
      },
      {
        "Action" : [
          "autoscaling:DetachInstances",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetInstanceProtection"
        ],
        "Effect" : "Allow",
        "Resource" : ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = ["arn:aws:lambda:*:*:function:${local.lambda_prefix}-${var.cluster_name}*"]
      }
    ]
  })
  tags = var.tags_map
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
  role       = aws_iam_role.lambda_iam_role.name
}

resource "aws_iam_policy" "lambda_obs_iam_policy" {
  count = var.tiering_enable_obs_integration && var.tiering_obs_name == "" ? 1 : 0
  name  = "${local.iam_prefix}-${var.cluster_name}-lambda-obs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
        ]
        Resource = ["arn:aws:s3:::${local.obs_name}"]
      }
    ]
  })
  tags = var.tags_map
}

resource "aws_iam_policy_attachment" "lambda_obs_policy_attachment" {
  count      = var.tiering_enable_obs_integration && var.tiering_obs_name == "" ? 1 : 0
  name       = "${local.iam_prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.lambda_obs_iam_policy[0].arn
  roles      = [aws_iam_role.lambda_iam_role.name]
}
