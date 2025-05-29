data "aws_caller_identity" "current" {}

resource "aws_kms_key" "kms_key" {
  enable_key_rotation     = true
  deletion_window_in_days = 20
  is_enabled              = true
  tags = merge(var.tags_map, {
    Name = var.name
  })
}

resource "aws_kms_alias" "kms_alias" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.kms_key.key_id
  depends_on    = [aws_kms_key.kms_key]
}

resource "aws_kms_key_policy" "kms_key_policy" {
  key_id = aws_kms_key.kms_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        Sid    = "Allow service-linked role use of the customer managed key",
        Effect = "Allow",
        Principal = {
          AWS = var.principal
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow service-linked role use of the customer managed key",
        Effect = "Allow",
        Principal = {
          AWS = var.principal
        },
        Action = [
          "kms:CreateGrant"
        ],
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : true
          }
        }
      }
    ]
  })
  depends_on = [aws_kms_key.kms_key]
}
