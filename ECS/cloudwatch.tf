# CloudWatch alarms for cost, ECS service health, and the load balancer.

# Billing metrics are only published in us-east-1, so we need a provider alias there.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# SNS topic for alarm notifications in the primary region (ap-northeast-1).
resource "aws_sns_topic" "slack_notify" {
  name = "kinn-slack-notify"
}

# SNS topic in us-east-1 for the billing alarm (alarm actions must be in the
# same region as the alarm).
resource "aws_sns_topic" "slack_notify_us_east_1" {
  provider = aws.us_east_1
  name     = "kinn-slack-notify"
}

# 1. Cost alarm: fires when the estimated monthly AWS charges exceed the threshold.
# Note: Billing metrics are only available in the us-east-1 region.
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  provider = aws.us_east_1

  alarm_name          = "estimated-charges-too-high"
  alarm_description   = "Estimated AWS charges exceeded 50 USD for the month"
  namespace           = "AWS/Billing"
  metric_name         = "EstimatedCharges"
  statistic           = "Maximum"
  period              = 21600 # 6 hours (billing metrics update a few times a day)
  evaluation_periods  = 1
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.slack_notify_us_east_1.arn]
  ok_actions    = [aws_sns_topic.slack_notify_us_east_1.arn]

  dimensions = {
    Currency = "USD"
  }
}

# 2. ECS metric alarm: fires when the service's CPU utilization stays high.
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "ecs-nginx-service-cpu-high"
  alarm_description   = "ECS nginx service average CPU utilization above 80%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.slack_notify.arn]
  ok_actions    = [aws_sns_topic.slack_notify.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.app_cluster.name
    ServiceName = aws_ecs_service.app_service.name
  }
}

# 3. Common alarm: fires when the load balancer returns too many 5XX errors.
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name         = "alb-5xx-errors-high"
  alarm_description  = "Application Load Balancer returned more than 10 5XX errors in 5 minutes"
  namespace          = "AWS/ApplicationELB"
  metric_name        = "HTTPCode_ELB_5XX_Count"
  statistic          = "Sum"
  period             = 300
  evaluation_periods = 1
  threshold          = 10
  alarm_actions      = [aws_sns_topic.slack_notify.arn]
  ok_actions         = [aws_sns_topic.slack_notify.arn]

  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
  }
}
