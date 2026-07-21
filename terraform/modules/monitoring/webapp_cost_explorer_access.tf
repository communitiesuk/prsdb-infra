# Allows the webapp ECS task role to query historical costs for the
# System Operator metrics dashboard's cost-per-transaction calculation.
# The webapp does not send BillingViewArn, so AWS authorizes the request against
# the Cost Explorer GetCostAndUsage request resource instead of a Billing View ARN.
# Resource-level restriction therefore cannot be used for this request.
# See https://docs.aws.amazon.com/service-authorization/latest/reference/list_ce.html#list_ce-action-GetCostAndUsage
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
