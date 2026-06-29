# Allows the webapp ECS task role to publish JVM/process metrics to CloudWatch
# via Micrometer's CloudWatch registry, and to read infrastructure metrics back via
# GetMetricStatistics to power the System Operator dashboard.
# Neither cloudwatch:PutMetricData nor cloudwatch:GetMetricStatistics supports
# resource-level permissions, so a wildcard is required.
# See https://docs.aws.amazon.com/service-authorization/latest/reference/list_amazoncloudwatch.html
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "webapp_publish_cloudwatch_metrics" {
  statement {
    actions   = ["cloudwatch:PutMetricData", "cloudwatch:GetMetricStatistics"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "webapp_publish_cloudwatch_metrics" {
  name   = "${var.environment_name}-webapp-publish-cloudwatch-metrics"
  policy = data.aws_iam_policy_document.webapp_publish_cloudwatch_metrics.json
}

resource "aws_iam_role_policy_attachment" "webapp_publish_cloudwatch_metrics" {
  role       = var.webapp_ecs_task_role_name
  policy_arn = aws_iam_policy.webapp_publish_cloudwatch_metrics.arn
}
