locals {
  base_name = var.iam_base_name != null ? var.iam_base_name : var.data_services_name
}

resource "aws_iam_policy" "ec2" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${local.base_name}-ec2-policy"
  tags = local.tags
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
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:AssignPrivateIpAddresses",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = ["arn:aws:secretsmanager:*:*:secret:${var.secret_prefix}*"]
      }
    ]
  })
}

resource "aws_iam_policy" "logging" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${local.base_name}-send-log-to-cloud-watch-policy"
  tags = local.tags
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
          "arn:aws:logs:*:*:log-group:/wekaio/${var.data_services_name}*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "autoscaling" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${local.base_name}-autoscaling-policy"
  tags = local.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "invoke_lambda_function" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${local.base_name}-invoke-lambda-function"
  tags = local.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          "arn:aws:lambda:*:*:function:${var.deploy_lambda_name}*",
          "arn:aws:lambda:*:*:function:${var.report_lambda_name}*",
          "arn:aws:lambda:*:*:function:${var.fetch_lambda_name}*",
          "arn:aws:lambda:*:*:function:${var.status_lambda_name}*",
        ]
      }
    ]
  })
}

resource "aws_iam_role" "this" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${local.base_name}-role"
  tags = local.tags
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
}

# Attach the IAM policies to the IAM role.
#
# These use `aws_iam_policy_attachment`, which is EXCLUSIVE: it owns the complete set of
# principals attached to a policy and detaches any it does not track. That is safe here
# only because every policy attached below is created by this module and named per
# deployment, so nothing else in the account attaches it.
#
# Do NOT use it for an AWS-managed policy (arn:aws:iam::aws:policy/...) or any
# caller-supplied policy ARN - use `aws_iam_role_policy_attachment` instead. Attaching a
# shared policy with the exclusive resource detaches it from every other role in the
# account; that is what caused issue #162.
resource "aws_iam_policy_attachment" "ec2" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${local.base_name}-ec2-policy-attachment"
  policy_arn = aws_iam_policy.ec2[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_policy_attachment" "logging" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${local.base_name}-log-policy-attachment"
  policy_arn = aws_iam_policy.logging[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_policy_attachment" "autoscaling" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${local.base_name}-autoscaling-policy-attachment"
  policy_arn = aws_iam_policy.autoscaling[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_policy_attachment" "lambda_invoke" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${local.base_name}-lambda-invoke-policy-attachment"
  policy_arn = aws_iam_policy.invoke_lambda_function[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attachment" {
  count      = var.instance_iam_profile_arn == "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.this[0].name
}

# Create an IAM instance profile
resource "aws_iam_instance_profile" "this" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${local.base_name}-instance-profile"
  role       = aws_iam_role.this[0].name
  tags       = local.tags
  depends_on = [aws_iam_role.this]
}
