data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # CloudFront access logs and CloudFront WAF logs are stored in us-east-1
  log_and_queue_services = [
    "logs.${data.aws_region.current.name}.amazonaws.com",
    "logs.us-east-1.amazonaws.com",
    "sqs.${data.aws_region.current.name}.amazonaws.com",
  ]
  performance_insights_service = "rds.${data.aws_region.current.name}.amazonaws.com"
}

resource "aws_iam_role" "read_only_investigator" {
  name               = "${var.environment_name}-read-only-investigator"
  assume_role_policy = data.aws_iam_policy_document.read_only_investigator_assume_role.json
}

data "aws_iam_policy_document" "read_only_investigator_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/*AWSReservedSSO_developer_role_*"]
    }
  }
}

data "aws_iam_policy" "read_only_access" {
  arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "read_only_investigator_read_only_access" {
  role       = aws_iam_role.read_only_investigator.name
  policy_arn = data.aws_iam_policy.read_only_access.arn
}

# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "read_only_investigator" {
  statement {
    sid       = "DecryptLogsAndDeadLetterQueues"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = local.log_and_queue_services
    }
  }

  statement {
    sid       = "ReadPerformanceInsights"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [local.performance_insights_service]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:service"
      values   = ["pi"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:aws:pi:service"
      values   = ["rds"]
    }
  }

  statement {
    sid       = "DenyOtherDecryption"
    effect    = "Deny"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "kms:ViaService"
      values   = concat(local.log_and_queue_services, [local.performance_insights_service])
    }
  }

  statement {
    sid    = "DenySecretValues"
    effect = "Deny"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:BatchGetSecretValue",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyObjectDownloads"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectTorrent",
      "s3:GetObjectVersionTorrent",
      "s3:GetObjectVersionForReplication",
      "s3-object-lambda:GetObject",
      "s3-object-lambda:GetObjectVersion",
    ]
    resources = ["*"]
  }

  statement {
    sid           = "DenyReceivingFromNonDeadLetterQueues"
    effect        = "Deny"
    actions       = ["sqs:ReceiveMessage"]
    not_resources = ["arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*-dead-letter-queue"]
  }

  statement {
    sid    = "DenyDataStoreConnections"
    effect = "Deny"
    actions = [
      "ssm:StartSession",
      "ssm:SendCommand",
      "ecs:ExecuteCommand",
      "ec2-instance-connect:*",
      "rds-db:connect",
      "rds-data:*",
      "elasticache:Connect",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "read_only_investigator" {
  name        = "${var.environment_name}-read-only-investigator"
  description = "Limits the read only investigator to metadata, logs, Performance Insights and dead letter queue messages"
  policy      = data.aws_iam_policy_document.read_only_investigator.json
}

resource "aws_iam_role_policy_attachment" "read_only_investigator" {
  role       = aws_iam_role.read_only_investigator.name
  policy_arn = aws_iam_policy.read_only_investigator.arn
}
