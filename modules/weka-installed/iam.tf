# Create an IAM role with a unique name
resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2-instance-role-${var.random_pet_id}"  # Use var.random_pet_id to make it unique

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

# Create an IAM policy for describing instances and accessing S3
resource "aws_iam_policy" "describe_instances_policy" {
  name        = "describe-instances-policy-${var.random_pet_id}"  # Make policy name unique
  description = "Policy to allow describing EC2 instances and accessing S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::cst-scenario-lab",                    # Permission to list the bucket
          "arn:aws:s3:::cst-scenario-lab/weka-installation/*" # Permission to get objects in this path
        ]
      }
    ]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "attach_describe_instances_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.describe_instances_policy.arn
}

# Create an instance profile with a unique name
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile-${var.random_pet_id}"  # Use var.random_pet_id to make it unique
  role = aws_iam_role.ec2_instance_role.name
}
