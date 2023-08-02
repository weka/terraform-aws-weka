resource "aws_iam_role" "event_iam_role" {
  name = "${var.prefix}-${var.cluster_name}-event-role"
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
}

resource "aws_iam_policy" "event_iam_policy" {
  name = "${var.prefix}-${var.cluster_name}-event-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          "arn:aws:states:*:*:stateMachine:${var.prefix}-${var.cluster_name}-scale-down-state-machine"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_policy_attachment" {
  policy_arn = aws_iam_policy.event_iam_policy.arn
  role       = aws_iam_role.event_iam_role.name
}
