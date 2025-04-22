resource "aws_flow_log" "vpc_accepted" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs_accepted.arn
  traffic_type    = "ACCEPT"
  vpc_id          = aws_vpc.main.id
}

resource "aws_flow_log" "vpc_rejected" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs_rejected.arn
  traffic_type    = "REJECT"
  vpc_id          = aws_vpc.main.id
}

# Flow logs are non-sensitive
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "vpc_flow_logs_accepted" {
  name              = "vpc-flow-logs-accepted-${var.environment_name}"
  retention_in_days = var.vpc_flow_cloudwatch_log_expiration_days
}

# Flow logs are non-sensitive
# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "vpc_flow_logs_rejected" {
  name              = "vpc-flow-logs-rejected-${var.environment_name}"
  retention_in_days = var.vpc_flow_cloudwatch_log_expiration_days
}
