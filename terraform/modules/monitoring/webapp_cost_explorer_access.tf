# Allows the webapp ECS task role to query historical costs for the
# System Operator metrics dashboard's cost-per-transaction calculation.
# Cost Explorer queries default to the account's primary billing view.
# See https://docs.aws.amazon.com/service-authorization/latest/reference/list_ce.html#list_ce-action-GetCostAndUsage
data "aws_iam_policy_document" "webapp_cost_explorer_access" {
  statement {
    actions   = ["ce:GetCostAndUsage"]
    resources = ["arn:aws:billing::${data.aws_caller_identity.current.account_id}:billingview/primary"]
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
