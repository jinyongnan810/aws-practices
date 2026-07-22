# Ship Lambda CloudWatch logs matching "SessionId" to S3.
# Since my account cannot use Kinesis Firehose, the subscription filter targets a
# small processor Lambda that decodes the log events and writes them to S3.
#
# NOTE: /aws/lambda/HelloWorldAPI is auto-created by AWS the first time the
# function runs. Import it before applying:
#   terraform import aws_cloudwatch_log_group.lambda_logs /aws/lambda/HelloWorldAPI

data "aws_caller_identity" "current" {}

# 1. Manage the Lambda's log group so we can attach a filter to it
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.hello_world_function.function_name}"
  retention_in_days = 14
}

# 2. Destination S3 bucket for the exported logs
resource "aws_s3_bucket" "lambda_logs" {
  bucket = "lambda-logs-${data.aws_caller_identity.current.account_id}"

  # Allow `terraform destroy` to delete the bucket even when it still holds logs
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "lambda_logs" {
  bucket                  = aws_s3_bucket.lambda_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Processor Lambda that writes filtered log events into the bucket
data "archive_file" "log_processor_zip" {
  type        = "zip"
  source_file = "log_processor.py"
  output_path = "log_processor.zip"
}

data "aws_iam_policy_document" "log_processor_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "log_processor_exec_role" {
  name               = "LambdaLogProcessorRole"
  assume_role_policy = data.aws_iam_policy_document.log_processor_assume_role.json
}

resource "aws_iam_role_policy_attachment" "log_processor_logs_attach" {
  role       = aws_iam_role.log_processor_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "log_processor_s3" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.lambda_logs.arn}/*"]
  }
}

resource "aws_iam_role_policy" "log_processor_s3" {
  name   = "LambdaLogProcessorS3Write"
  role   = aws_iam_role.log_processor_exec_role.id
  policy = data.aws_iam_policy_document.log_processor_s3.json
}

resource "aws_lambda_function" "log_processor" {
  function_name    = "HelloWorldLogProcessor"
  filename         = data.archive_file.log_processor_zip.output_path
  role             = aws_iam_role.log_processor_exec_role.arn
  handler          = "log_processor.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.log_processor_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.lambda_logs.id
      PREFIX      = "logs/"
    }
  }
}

# 4. Allow CloudWatch Logs to invoke the processor Lambda
resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  statement_id  = "AllowCloudWatchLogsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_processor.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
}

# 5. Subscription filter forwarding only records containing "SessionId"
resource "aws_cloudwatch_log_subscription_filter" "session_id" {
  name            = "SessionIdToS3"
  log_group_name  = aws_cloudwatch_log_group.lambda_logs.name
  filter_pattern  = "SessionId"
  destination_arn = aws_lambda_function.log_processor.arn

  depends_on = [aws_lambda_permission.allow_cloudwatch_logs]
}
