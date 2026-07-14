# Allows the webapp ECS task role to query historical costs for the
# System Operator metrics dashboard's cost-per-transaction calculation.
# ce:GetCostAndUsage does not support resource-level permissions, so a wildcard is required.
# See https://docs.aws.amazon.com/service-authorization/latest/reference/list_awscostexplorerservice.html
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "webapp_cost_explorer_access" {
  statement {
    actions   = ["ce:GetCostAndUsage"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "webapp_cost_explorer_access" {
  name   = "${var.environment_name}-webapp-read-cost-and-usage"
  policy = data.aws_iam_policy_document.webapp_cost_explorer_access.json
}

resource "aws_iam_role_policy_attachment" "webapp_cost_explorer_access" {
  role       = var.webapp_ecs_task_role_name
  policy_arn = aws_iam_policy.webapp_cost_explorer_access.arn
}
