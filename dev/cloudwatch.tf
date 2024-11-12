# CloudWatch Event rule to trigger the Lambda function every 15 minutes
resource "aws_cloudwatch_event_rule" "run_every_15_minutes" {
  name                 = "AutoDestroyInstancesRule"
  description          = "Triggers the AutoDestroy Lambda every 15 minutes"
  schedule_expression  = "rate(15 minutes)"
}

# Attach Lambda function as the target of the CloudWatch Event rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.run_every_15_minutes.name
  target_id = "AutoDestroyLambdaTarget"
  arn       = aws_lambda_function.auto_destroy_lambda.arn
}

# Grant CloudWatch Events permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch_invoke" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_destroy_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.run_every_15_minutes.arn
}
