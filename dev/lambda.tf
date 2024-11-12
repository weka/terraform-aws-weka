# Upload Lambda zip to S3 (using aws_s3_object for the existing bucket)
resource "aws_s3_object" "autodestroy_python" {
  bucket = var.s3_bucket_name
  key    = "destroy-instances.zip"
  source = "./python/auto-destroy/auto-destroy.zip"
}

# Create Lambda function with go1.x runtime
resource "aws_lambda_function" "auto_destroy_lambda" {
  function_name = "AutoDestroyInstances"
  role          = aws_iam_role.lambda_exec_role.arn  # Ensure IAM role is defined separately
  handler       = "destroy-instances"
  runtime       = "python3.8"
  s3_bucket     = var.s3_bucket_name
  s3_key        = aws_s3_object.autodestroy_python.key

  environment {
    variables = {
      TAG_KEY         = var.expiration_tag_key
      TAG_VALUE       = var.expiration_tag_value
      EXPIRATION_TIME = tostring(var.expiration_time)
    }
  }
}
