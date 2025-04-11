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
        rule_action_override {
          # This rule blocks request bodies over 8KB in size, but PRSDB needs file uploads so we remove this restriction
          # The default maximum request body size that can be inspected when using cloudfront web ACLs is 16KB, so this
          # does limit the effectiveness of the other rules here. The limit can be increased to up to 64KB if necessary
          # at extra cost.
          # More info here: https://docs.aws.amazon.com/waf/latest/developerguide/web-acl-setting-body-inspection-limit.html
          # We have a separate rule enforcing a size constraint to ensure only file-upload endpoints accept large requests.
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-common-exploit"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "size-constraint-on-non-file-upload-requests"
    priority = 5

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          size_constraint_statement {
            comparison_operator = "GT" # Greater than
            size                = 8192 # 8KB
            field_to_match {
              body {
                oversize_handling = "MATCH"
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          not_statement {
            statement {
              byte_match_statement {
                positional_constraint = "CONTAINS"
                search_string         = "file-upload"
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-block-large-requests"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-rules-known-bad-inputs-rule-set"
    priority = 6

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
    priority = 7

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
    priority = 8

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
    priority = 9

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
    priority = 10

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