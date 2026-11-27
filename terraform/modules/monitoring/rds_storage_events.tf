resource "aws_cloudwatch_event_rule" "rds_storage_ceiling" {
  count       = var.database_storage_autoscaling_enabled ? 1 : 0
  name        = "${var.environment_name}-rds-storage-ceiling"
  description = "Alert when RDS storage approaches its autoscaling ceiling"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Instance Event"]
    detail = {
      EventID   = ["RDS-EVENT-0225"]
      SourceArn = ["arn:aws:rds:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:db:${var.database_identifier}"]
    }
  })
}

data "aws_iam_policy_document" "rds_storage_event_assume_role" {
  count = var.database_storage_autoscaling_enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_storage_event" {
  count              = var.database_storage_autoscaling_enabled ? 1 : 0
  name               = "${var.environment_name}-rds-storage-ceiling-event"
  assume_role_policy = data.aws_iam_policy_document.rds_storage_event_assume_role[0].json
}

data "aws_iam_policy_document" "rds_storage_event_publish" {
  count = var.database_storage_autoscaling_enabled ? 1 : 0
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.non_critical_alarm_sns_topic.arn]
  }
}

resource "aws_iam_role_policy" "rds_storage_event_publish" {
  count  = var.database_storage_autoscaling_enabled ? 1 : 0
  name   = "publish-rds-storage-ceiling"
  role   = aws_iam_role.rds_storage_event[0].id
  policy = data.aws_iam_policy_document.rds_storage_event_publish[0].json
}

resource "aws_cloudwatch_event_target" "rds_storage_ceiling" {
  count    = var.database_storage_autoscaling_enabled ? 1 : 0
  rule     = aws_cloudwatch_event_rule.rds_storage_ceiling[0].name
  arn      = aws_sns_topic.non_critical_alarm_sns_topic.arn
  role_arn = aws_iam_role.rds_storage_event[0].arn
}
