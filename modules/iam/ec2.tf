# Create an IAM policy

locals {
  obs_name = var.tiering_obs_name == "" ? lower("${local.obs_prefix}-${var.cluster_name}-obs") : var.tiering_obs_name
}

resource "aws_iam_policy" "backend_eni_iam_policy" {
  name = "${local.iam_prefix}-${var.cluster_name}-eni-policy"
  tags = var.tags_map
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:AttachNetworkInterface",
          "ec2:CreateNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DeleteNetworkInterface",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "backend_obs_iam_policy" {
  count = var.tiering_enable_obs_integration ? 1 : 0
  name  = "${local.iam_prefix}-${var.cluster_name}-obs-policy"
  tags  = var.tags_map
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = ["arn:aws:s3:::${local.obs_name}/*"]
      }
    ]
  })
}

resource "aws_iam_policy" "additional" {
  count = var.additional_iam_policy_statement != null ? 1 : 0
  name  = "${local.iam_prefix}-${var.cluster_name}-additional-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.additional_iam_policy_statement
  })
  tags = var.tags_map
}

resource "aws_iam_policy" "invoke_lambda_function" {
  name = "${local.iam_prefix}-${var.cluster_name}-invoke-lambda-function"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:*:*:function:${local.lambda_prefix}-${var.cluster_name}*"
        ]
      }
    ]
  })
  tags = var.tags_map
}

# Create an IAM policy
resource "aws_iam_policy" "backend_log_iam_policy" {
  name = "${local.iam_prefix}-${var.cluster_name}-send-log-to-cloud-watch-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/wekaio/${local.ec2_prefix}-${var.cluster_name}*"
        ]
      }
    ]
  })
  tags = var.tags_map
}

# Create an IAM role
resource "aws_iam_role" "iam_role" {
  name = "${local.iam_prefix}-${var.cluster_name}-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = var.tags_map
}

# Attach the IAM policy to the IAM role
resource "aws_iam_policy_attachment" "backend_eni_role_attachment" {
  name       = "${local.iam_prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.backend_eni_iam_policy.arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "backend_obs_role_attachment" {
  count      = var.tiering_enable_obs_integration ? 1 : 0
  name       = "${local.iam_prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.backend_obs_iam_policy[0].arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "additional" {
  count      = var.additional_iam_policy_statement != null ? 1 : 0
  name       = "${aws_iam_policy.additional[0].name}-attachment"
  policy_arn = aws_iam_policy.additional[0].arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "backend_log_role_attachment" {
  name       = "${local.iam_prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.backend_log_iam_policy.arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "invoke_lambda_function_attachment" {
  name       = "${local.iam_prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.invoke_lambda_function.arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.iam_role.name
}

# Create an IAM instance profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${local.iam_prefix}-${var.cluster_name}-instance-profile"
  role = aws_iam_role.iam_role.name
  tags = var.tags_map
}
