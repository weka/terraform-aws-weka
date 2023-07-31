resource "aws_iam_policy" "ec2" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${var.clients_name}-ec2-policy"

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
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "logging" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${var.clients_name}-send-log-to-cloud-watch-policy"

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
          "arn:aws:logs:*:*:log-group:/wekaio/${var.clients_name}*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "autoscaling" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${var.clients_name}-autoscaling-policy"

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

resource "aws_iam_role" "this" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${var.clients_name}-iam-role"

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

# Attach the IAM policy to the IAM role
resource "aws_iam_policy_attachment" "ec2" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${var.clients_name}-ec2-policy-attachment"
  policy_arn = aws_iam_policy.ec2[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_policy_attachment" "logging" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${var.clients_name}-log-policy-attachment"
  policy_arn = aws_iam_policy.logging[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_policy_attachment" "autoscaling" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "${var.clients_name}-autoscaling-policy-attachment"
  policy_arn = aws_iam_policy.autoscaling[0].arn
  roles      = [aws_iam_role.this[0].name]
}

resource "aws_iam_policy_attachment" "ec2_ssm_attachment" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name       = "ec2-ssm-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  roles      = [aws_iam_role.this[0].name]
}

# Create an IAM instance profile
resource "aws_iam_instance_profile" "this" {
  count = var.instance_iam_profile_arn == "" ? 1 : 0

  name = "${var.clients_name}-instance-profile"
  role = aws_iam_role.this[0].name
}
