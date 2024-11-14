# Create an IAM policy with a unique name
resource "aws_iam_policy" "ec2_describe_instances" {
  name        = "EC2DescribeInstances-${random_pet.fun-name.id}"  # Use random_pet for uniqueness
  path        = "/"
  description = "Allows EC2 instances to describe other instances"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterfaces"
],
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Create an IAM role with a unique name
resource "aws_iam_role" "ec2_instance_role" {
  name = "EC2InstanceRole-${random_pet.fun-name.id}"  # Use random_pet for uniqueness

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the policy to the IAM role
resource "aws_iam_role_policy_attachment" "attach_ec2_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_describe_instances.arn
}

# Create an instance profile with a unique name
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2InstanceProfile-${random_pet.fun-name.id}"  # Use random_pet for uniqueness
  role = aws_iam_role.ec2_instance_role.name
}
