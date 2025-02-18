resource "aws_wafv2_web_acl" "main" {
  name        = var.environment_name
  description = "Web ACL to restrict traffic to CloudFront"
  provider    = aws.us-east-1
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf"
    sampled_requests_enabled   = false
  }

  custom_response_body {
    key          = "ip_error"
    content      = "This resource is not available to your IP address"
    content_type = "TEXT_PLAIN"
  }

  dynamic "rule" {
    # [{}] causes 1 instance of the block to be created, [] causes 0 instances of the block
    for_each = length(var.ip_allowlist) > 0 ? [{}] : []
    content {
      name     = "ip-allowlist"
      priority = 2
      action {
        block {
          custom_response {
            custom_response_body_key = "ip_error"
            response_code            = 403
          }
        }
      }

      statement {
        not_statement {
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.allowed_ips.arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "waf-block-non-allowed-ip"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "aws-managed-rules-amazon-ip-reputation-list"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-disreputable-ip"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-rules-common-rule-set"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-common-exploit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-rules-known-bad-inputs-rule-set"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-bad-input-exploit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-rules-sqli-rule-set"
    priority = 6

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-sql-exploit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-rules-linux-rule-set"
    priority = 7

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-linux-exploit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-rules-unix-rule-set"
    priority = 8

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesUnixRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-unix-exploit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "overall-ip-rate-limit"
    priority = 9

    action {
      block {
        custom_response {
          response_code = 429
        }
      }
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = 2000
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-overall-ip-rate-limit"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_ip_set" "allowed_ips" {
  provider = aws.us-east-1

  name               = "waf-allowed-ip-set-${var.environment_name}"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.ip_allowlist
}