locals {
  sfn_function_name = [aws_lambda_function.fetch_lambda.function_name, aws_lambda_function.scale_down_lambda.function_name, aws_lambda_function.terminate_lambda.function_name, aws_lambda_function.transient_lambda.function_name]
  cloudwatch_prefix = lookup(var.custom_prefix, "cloudwatch", var.prefix)
  sfn_prefix        = lookup(var.custom_prefix, "sfn", var.prefix)
}
resource "aws_cloudwatch_log_group" "sfn_log_group" {
  name              = "/aws/vendedlogs/states/${local.cloudwatch_prefix}/${var.cluster_name}-scale-down-sfn"
  retention_in_days = 30
  tags              = var.tags_map
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  name                = "${local.cloudwatch_prefix}-${var.cluster_name}-scale-down-trigger-rule"
  schedule_expression = "rate(1 minute)"
  description         = "CloudWatch trigger scale down step function every 1 minute"
  tags = merge(var.tags_map, {
    Name = "${local.cloudwatch_prefix}-${var.cluster_name}-scale-down-trigger-rule"
  })
}

resource "aws_cloudwatch_event_target" "step_function_event_target" {
  target_id  = "TriggerStepFunctionFromCloudWatch"
  rule       = aws_cloudwatch_event_rule.event_rule.name
  arn        = aws_sfn_state_machine.scale_down_state_machine.arn
  role_arn   = local.event_iam_role_arn
  depends_on = [aws_cloudwatch_event_rule.event_rule, aws_sfn_state_machine.scale_down_state_machine]
}

resource "aws_lambda_permission" "invoke_lambda_permission" {
  count         = length(local.sfn_function_name)
  action        = "lambda:InvokeFunction"
  function_name = local.sfn_function_name[count.index]
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule.arn
  statement_id  = "AllowExecutionFromCloudWatch"
}

resource "aws_sfn_state_machine" "scale_down_state_machine" {
  name       = "${local.sfn_prefix}-${var.cluster_name}-scale-down-state-machine"
  role_arn   = local.sfn_iam_role_arn
  definition = <<EOF
  {
  "Comment": "Run Fetch function for scale down",
  "StartAt": "Fetch",
  "States": {
    "Fetch": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.fetch_lambda.arn}",
      "Next": "ScaleDown"
    },
    "ScaleDown" : {
        "Type": "Task",
        "Resource": "${aws_lambda_function.scale_down_lambda.arn}",
        "Next": "Terminate"
    },
    "Terminate":{
      "Type": "Task",
        "Resource": "${aws_lambda_function.terminate_lambda.arn}",
      "Next": "ErrorCheck"
    },
    "ErrorCheck" :{
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.TransientErrors",
          "IsNull": false,
          "Next": "Transient"
		}
       ],
      "Default": "Success"
    },
    "Success": {
      "Type": "Succeed",
      "Comment": "Scale Down Succeed."
    },
    "Transient": {
      "Type": "Task",
        "Resource": "${aws_lambda_function.transient_lambda.arn}",

    "End":true
  }
  }
}
EOF

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = merge(var.tags_map, {
    Name = "${local.sfn_prefix}-${var.cluster_name}-scale-up-sfn"
  })
  depends_on = [aws_lambda_function.scale_down_lambda, aws_lambda_function.fetch_lambda, aws_lambda_function.terminate_lambda, aws_lambda_function.transient_lambda, aws_cloudwatch_log_group.sfn_log_group]
}
