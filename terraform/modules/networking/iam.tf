data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "vpc-flow-logs-role-${var.environment_name}"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "vpc_flow_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-cloudwatch-policy-${var.environment_name}"
  role = aws_iam_role.vpc_flow_logs.id

  policy = data.aws_iam_policy_document.vpc_flow_logs.json
}
