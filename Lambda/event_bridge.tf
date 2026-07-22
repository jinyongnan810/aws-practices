# Trigger the HelloWorldAPI Lambda every Monday at 08:00 Tokyo time

# 1. Trust relationship allowing EventBridge Scheduler to assume the role
data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

# 2. Role the scheduler uses to invoke the Lambda
resource "aws_iam_role" "scheduler_exec_role" {
  name               = "HelloWorldSchedulerRole"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

# 3. Permission to invoke the specific Lambda alias
data "aws_iam_policy_document" "scheduler_invoke_lambda" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_alias.current.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name   = "HelloWorldSchedulerInvokeLambda"
  role   = aws_iam_role.scheduler_exec_role.id
  policy = data.aws_iam_policy_document.scheduler_invoke_lambda.json
}

# 4. The weekly schedule (every Monday 08:00 Asia/Tokyo)
resource "aws_scheduler_schedule" "hello_world_weekly" {
  name = "HelloWorldWeeklyMonday"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0 8 ? * MON *)"
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = aws_lambda_alias.current.arn
    role_arn = aws_iam_role.scheduler_exec_role.arn

    input = jsonencode({
      action    = "read"
      SessionId = "abc123"
    })
  }
}
