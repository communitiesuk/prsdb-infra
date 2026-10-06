module "waf_logs" {
  source = "../encrypted_log_group"

  providers = {
    aws = aws.us-east-1
  }

  log_group_name     = "aws-waf-logs-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}

moved {
  from = aws_cloudwatch_log_group.main
  to   = module.waf_logs.aws_cloudwatch_log_group.main
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  provider = aws.us-east-1

  log_destination_configs = [module.waf_logs.log_group_arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  logging_filter {
    default_behavior = "DROP"
    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ALL"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}

module "load_balancer_waf_logs" {
  source = "../encrypted_log_group"

  log_group_name     = "aws-waf-logs-alb-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}

resource "aws_wafv2_web_acl_logging_configuration" "load_balancer" {
  log_destination_configs = [module.load_balancer_waf_logs.log_group_arn]
  resource_arn            = aws_wafv2_web_acl.load_balancer.arn

  redacted_fields {
    single_header {
      name = lower(local.cloudfront_header_name)
    }
  }

  logging_filter {
    default_behavior = "DROP"
    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ALL"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}

module "cloudfront_access_logs" {
  source = "../encrypted_log_group"

  providers = {
    aws = aws.us-east-1
  }

  log_group_name     = "cloudfront-access-logs-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}

resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  provider = aws.us-east-1

  name         = module.cloudfront_access_logs.name
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.main.arn
}

resource "aws_cloudwatch_log_delivery_destination" "cloudfront" {
  provider = aws.us-east-1

  name          = module.cloudfront_access_logs.name
  output_format = "json"

  delivery_destination_configuration {
    destination_resource_arn = module.cloudfront_access_logs.log_group_arn
  }
}

data "aws_caller_identity" "current" {
  provider = aws.us-east-1
}

data "aws_iam_policy_document" "cloudfront_log_delivery" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${module.cloudfront_access_logs.log_group_arn}:log-stream:*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "cloudfront_log_delivery" {
  provider = aws.us-east-1

  policy_name     = module.cloudfront_access_logs.name
  policy_document = data.aws_iam_policy_document.cloudfront_log_delivery.json
}

resource "aws_cloudwatch_log_delivery" "cloudfront" {
  provider = aws.us-east-1

  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cloudfront.arn
  # All standard access-log fields except cookies.
  record_fields = [
    "date",
    "time",
    "x-edge-location",
    "sc-bytes",
    "c-ip",
    "cs-method",
    "cs(Host)",
    "cs-uri-stem",
    "sc-status",
    "cs(Referer)",
    "cs(User-Agent)",
    "cs-uri-query",
    "x-edge-result-type",
    "x-edge-request-id",
    "x-host-header",
    "cs-protocol",
    "cs-bytes",
    "time-taken",
    "x-forwarded-for",
    "ssl-protocol",
    "ssl-cipher",
    "x-edge-response-result-type",
    "cs-protocol-version",
    "fle-status",
    "fle-encrypted-fields",
    "c-port",
    "time-to-first-byte",
    "x-edge-detailed-result-type",
    "sc-content-type",
    "sc-content-len",
    "sc-range-start",
    "sc-range-end",
  ]

  depends_on = [aws_cloudwatch_log_resource_policy.cloudfront_log_delivery]
}
