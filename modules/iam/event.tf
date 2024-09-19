resource "aws_iam_role" "event_iam_role" {
  name = "${local.iam_prefix}-${var.cluster_name}-event-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["events.amazonaws.com", "states.amazonaws.com"]
        }
      }
    ]
  })
  tags = var.tags_map
}

resource "aws_iam_policy" "event_iam_policy" {
  name = "${local.iam_prefix}-${var.cluster_name}-event-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          "arn:aws:states:*:*:stateMachine:${local.sfn_prefix}-${var.cluster_name}-scale-down-state-machine"
        ]
      }
    ]
  })
  tags = var.tags_map
}

resource "aws_iam_role_policy_attachment" "event_policy_attachment" {
  policy_arn = aws_iam_policy.event_iam_policy.arn
  role       = aws_iam_role.event_iam_role.name
}
