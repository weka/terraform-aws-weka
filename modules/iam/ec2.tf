# Create an IAM policy
resource "aws_iam_policy" "backend_eni_iam_policy" {
  name = "${var.prefix}-${var.cluster_name}-eni-policy"

  policy = jsonencode({
    Version   = "2012-10-17"
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
  count  = var.obs_name == "" ? 0 : 1
  name   = "${var.prefix}-${var.cluster_name}-obs-policy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*Object",
        ]
        Resource = ["arn:aws:s3:::${var.obs_name}/*"]
      }
    ]
  })
}

# Create an IAM policy
resource "aws_iam_policy" "backend_log_iam_policy" {
  name = "${var.prefix}-${var.cluster_name}-send-log-to-cloud-watch-policy"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:*:*"
        ]
      }
    ]
  })
}

# Create an IAM role
resource "aws_iam_role" "iam_role" {
  name = "${var.prefix}-${var.cluster_name}-iam-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the IAM policy to the IAM role
resource "aws_iam_policy_attachment" "backend_eni_role_attachment" {
  name       = "${var.prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.backend_eni_iam_policy.arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "backend_obs_role_attachment" {
  count      = var.obs_name == "" ? 0 : 1
  name       = "${var.prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.backend_obs_iam_policy[0].arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "backend_log_role_attachment" {
  name       = "${var.prefix}-${var.cluster_name}-policy-attachment"
  policy_arn = aws_iam_policy.backend_log_iam_policy.arn
  roles      = [aws_iam_role.iam_role.name]
}

resource "aws_iam_policy_attachment" "ec2_ssm_attachment" {
  name       = "ec2-ssm-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  roles      = [aws_iam_role.iam_role.name]
}

# Create an IAM instance profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.prefix}-${var.cluster_name}-instance-profile"
  role = aws_iam_role.iam_role.name
}
