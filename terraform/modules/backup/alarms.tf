locals {
  non_critical_alarm_actions = var.non_critical_alarm_sns_topic_arn == null ? [] : [var.non_critical_alarm_sns_topic_arn]
}

resource "aws_cloudwatch_event_rule" "backup_failure" {
  name        = "${var.environment_name}-backup-failure"
  description = "Capture AWS Backup jobs that failed or completed with issues, and continuous backups that stopped"

  event_pattern = jsonencode({
    source = ["aws.backup"]
    "$or" = [
      {
        detail-type = ["Backup Job State Change"]
        detail = {
          state = ["FAILED", "ABORTED", "EXPIRED", "PARTIAL"]
        }
      },
      {
        detail-type = ["Backup Job State Change"]
        detail = {
          state         = ["COMPLETED"]
          resourceType  = ["S3"]
          statusMessage = [{ "anything-but" = [""] }]
        }
      },
      {
        detail-type = ["Recovery Point State Change"]
        detail = {
          status = ["STOPPED"]
        }
      },
    ]
  })
}

module "backup_failure_log_group" {
  source = "../encrypted_log_group"

  log_group_name     = "${var.environment_name}-backup-failure"
  log_retention_days = 30
}

data "aws_iam_policy_document" "backup_failure_log_policy" {
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream"]

    resources = [
      "${module.backup_failure_log_group.log_group_arn}:*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["logs:PutLogEvents"]

    resources = [
      "${module.backup_failure_log_group.log_group_arn}:*:*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "delivery.logs.amazonaws.com"
      ]
    }

    condition {
      test     = "ArnEquals"
      values   = [aws_cloudwatch_event_rule.backup_failure.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "backup_failure_log_policy" {
  policy_document = data.aws_iam_policy_document.backup_failure_log_policy.json
  policy_name     = "${var.environment_name}-backup-failure-log-policy"
}

resource "aws_cloudwatch_event_target" "backup_failure_to_logs" {
  rule = aws_cloudwatch_event_rule.backup_failure.name
  arn  = module.backup_failure_log_group.log_group_arn
}

resource "aws_cloudwatch_log_metric_filter" "backup_failure" {
  log_group_name = module.backup_failure_log_group.name
  name           = "${var.environment_name}-backup-failure"
  pattern        = "{ $.source = \"aws.backup\" }"

  metric_transformation {
    name      = "${var.environment_name}-backup-failure"
    namespace = "LogMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "backup_failure" {
  alarm_name          = "${var.environment_name}-backup-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = aws_cloudwatch_log_metric_filter.backup_failure.name
  namespace           = "LogMetrics"
  evaluation_periods  = 1
  period              = 60
  threshold           = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  alarm_description = <<-EOT
    An AWS Backup job failed or completed with issues, or a continuous backup stopped, so S3 backups may be incomplete.
    Find the event in the ${module.backup_failure_log_group.name} log group and the job under Jobs in the AWS Backup console,
    fix the cause, then check the next backup job completes without a status message.
  EOT
  alarm_actions     = local.non_critical_alarm_actions
}
