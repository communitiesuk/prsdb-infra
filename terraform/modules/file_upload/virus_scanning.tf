resource "aws_guardduty_malware_protection_plan" "quarantine_scanning" {
  role = aws_iam_role.guardduty_malware_protection_role.arn

  protected_resource {
    s3_bucket {
      bucket_name = module.quarantine_bucket.bucket
    }
  }

  actions {
    tagging {
      status = "ENABLED"
    }
  }

  tags = {
    "Name" = "quarantine-scanning-${var.environment_name}"
  }
}

resource "aws_iam_role" "guardduty_malware_protection_role" {
  name = "guardduty-malware-protection-role-${var.environment_name}"

  assume_role_policy = data.aws_iam_policy_document.guardduty_malware_protection_assume_role.json
}

resource "aws_iam_role_policy_attachment" "guardduty_malware_protection_policy_attachment" {
  role       = aws_iam_role.guardduty_malware_protection_role.name
  policy_arn = aws_iam_policy.guardduty_malware_protection_policy.arn
}

resource "aws_iam_policy" "guardduty_malware_protection_policy" {
  name   = "malware-protection-policy"
  policy = data.aws_iam_policy_document.guardduty_malware_protection_policy.json
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Following the template from the AWS documentation: https://docs.aws.amazon.com/guardduty/latest/ug/malware-protection-s3-iam-policy-prerequisite.html
# tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "guardduty_malware_protection_policy" {
  statement {
    sid    = "AllowManagedRuleToSendS3EventsToGuardDuty"
    effect = "Allow"
    actions = [
      "events:PutRule",
      "events:DeleteRule",
      "events:PutTargets",
      "events:RemoveTargets"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*"
    ]
    condition {
      test     = "StringLike"
      variable = "events:ManagedBy"
      values   = ["malware-protection-plan.guardduty.amazonaws.com"]
    }
  }

  statement {
    sid    = "AllowGuardDutyToMonitorEventBridgeManagedRule"
    effect = "Allow"
    actions = [
      "events:DescribeRule",
      "events:ListTargetsByRule"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*"
    ]
  }

  statement {
    sid    = "AllowPostScanTag"
    effect = "Allow"
    actions = [
      "s3:PutObjectTagging",
      "s3:GetObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:GetObjectVersionTagging"
    ]
    resources = [
      "${module.quarantine_bucket.bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowEnableS3EventBridgeEvents"
    effect = "Allow"
    actions = [
      "s3:PutBucketNotification",
      "s3:GetBucketNotification"
    ]
    resources = [
      module.quarantine_bucket.bucket_arn
    ]
  }

  statement {
    sid    = "AllowPutValidationObject"
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${module.quarantine_bucket.bucket_arn}/malware-protection-resource-validation-object"
    ]
  }

  statement {
    sid    = "AllowCheckBucketOwnership"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      module.quarantine_bucket.bucket_arn
    ]
  }

  statement {
    sid    = "AllowMalwareScan"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "${module.quarantine_bucket.bucket_arn}/*"
    ]
  }

  statement {
    sid    = "AllowDecryptForMalwareScan"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.quarantine_bucket_encryption_key.arn
    ]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "guardduty_malware_protection_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["malware-protection-plan.guardduty.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_cloudwatch_event_rule" "process_scan_complete_event_rule" {
  name        = "process-scan-complete-event-rule-${var.environment_name}"
  description = "Rule to process GuardDuty malware scan complete events"
  event_pattern = jsonencode({
    source = ["aws.guardduty"]
    detail-type = ["GuardDuty Malware Protection Object Scan Result"]
  })
}

resource "aws_cloudwatch_event_target" "process_scan_complete_event_target" {
  target_id = "process-scan-complete-event-target-${var.environment_name}"
  rule      = aws_cloudwatch_event_rule.process_scan_complete_event_rule.name
  arn       = var.ecs_cluster_arn
  role_arn    = aws_iam_role.event_bridge_invoke_ecs_task_role.arn
  ecs_target {
    launch_type         = "FARGATE"
    task_count          = 1
    task_definition_arn = data.aws_ecs_task_definition.webapp_task_definition.arn

    network_configuration {
      subnets         = var.private_subnet_ids
      assign_public_ip = false
      security_groups  = var.ecs_security_group_ids
    }
    platform_version = "LATEST"
  }
  input = jsonencode({
    containerOverrides = [
      {
        name = "prsdb-webapp",
        environment = [
          {
            name  = "SPRING_PROFILES_ACTIVE"
            value = "web-server-deactivated,example-email-sender"
          },
        ]
      }
    ]
  })
}

data "aws_ecs_task_definition" "webapp_task_definition" {
  task_definition = "prsdb-webapp-${var.environment_name}"
}

resource "aws_iam_role" "event_bridge_invoke_ecs_task_role" {
  name = "event-bridge-invoke-ecs-task-role-${var.environment_name}"

  assume_role_policy = data.aws_iam_policy_document.event_bridge_invoke_ecs_task_assume_role.json
}

data "aws_iam_policy_document" "event_bridge_invoke_ecs_task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "event_bridge_invoke_ecs_task_policy_attachment" {
  role       = aws_iam_role.event_bridge_invoke_ecs_task_role.name
  policy_arn = aws_iam_policy.event_bridge_invoke_ecs_task_custom_policy.arn
}

resource "aws_iam_policy" "event_bridge_invoke_ecs_task_custom_policy" {
  name = "event-bridge-invoke-ecs-task-custom-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = [
          data.aws_ecs_task_definition.webapp_task_definition.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          data.aws_ecs_task_definition.webapp_task_definition.execution_role_arn,
          data.aws_ecs_task_definition.webapp_task_definition.task_role_arn,
        ]
      }
    ]
  })
}