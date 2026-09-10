# Capture ECS Task State Change events for scheduled tasks that ran but exited
# with a non-zero exit code (i.e. the job started but failed to complete).
resource "aws_cloudwatch_event_rule" "scheduled_task_execution_failure" {
  name        = "${var.environment_name}-scheduled-task-execution-failure"
  description = "Capture scheduled ECS tasks that stopped with a non-zero exit code"

  event_pattern = jsonencode({
    source      = ["aws.ecs"]
    detail-type = ["ECS Task State Change"]
    detail = {
      clusterArn = [aws_ecs_cluster.scheduled_tasks.arn]
      lastStatus = ["STOPPED"]
      containers = {
        exitCode = [{ "anything-but" = [0] }]
      }
    }
  })
}

module "scheduled_task_execution_failure_log_group" {
  source = "../encrypted_log_group"

  log_group_name     = "${var.environment_name}-scheduled-task-execution-failure"
  log_retention_days = 1
}

data "aws_iam_policy_document" "scheduled_task_execution_failure_log_policy" {
  statement {
    effect  = "Allow"
    actions = ["logs:CreateLogStream"]

    resources = [
      "${module.scheduled_task_execution_failure_log_group.log_group_arn}:*"
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
      "${module.scheduled_task_execution_failure_log_group.log_group_arn}:*:*"
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
      values   = [aws_cloudwatch_event_rule.scheduled_task_execution_failure.arn]
      variable = "aws:SourceArn"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "scheduled_task_execution_failure_log_policy" {
  policy_document = data.aws_iam_policy_document.scheduled_task_execution_failure_log_policy.json
  policy_name     = "${var.environment_name}-scheduled-task-execution-failure-log-policy"
}

resource "aws_cloudwatch_event_target" "scheduled_task_execution_failure_to_logs" {
  rule = aws_cloudwatch_event_rule.scheduled_task_execution_failure.name
  arn  = module.scheduled_task_execution_failure_log_group.log_group_arn
}

resource "aws_cloudwatch_log_metric_filter" "scheduled_task_execution_failure" {
  log_group_name = module.scheduled_task_execution_failure_log_group.name
  name           = "scheduled-task-execution-failure-${var.environment_name}"
  pattern        = "{ $.detail-type = \"ECS Task State Change\" }"

  metric_transformation {
    name      = "scheduled-task-execution-failure-${var.environment_name}"
    namespace = "LogMetrics"
    value     = "1"
  }
}
