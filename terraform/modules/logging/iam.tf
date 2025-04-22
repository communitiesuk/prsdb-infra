data "aws_caller_identity" "current" {}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "cloudwatch_logging" {
  statement {
    actions = [
      "cloudwatch:PutMetricData",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy"
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["*"]
  }
}
