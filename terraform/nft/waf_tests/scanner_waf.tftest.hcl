mock_provider "aws" {}

mock_provider "random" {}

variables {
  environment_name               = "nft"
  ssl_certs_created              = false
  public_subnet_ids              = ["subnet-0123456789abcdef0"]
  vpc_id                         = "vpc-0123456789abcdef0"
  application_port               = 8080
  cloudfront_domain_names        = ["nft.example.com"]
  load_balancer_domain_name      = "nft.lb.example.com"
  simulator_host                 = "nft.lb.example.com"
  detectify_ips                  = ["37.200.119.11/32", "52.17.9.21/32"]
  cloudwatch_log_expiration_days = 60
  use_aws_shield_advanced        = false
}

run "nft_scanner_uses_cloudfront_viewer_ip" {
  command = plan

  providers = {
    aws           = aws
    aws.us-east-1 = aws
    random        = random
  }

  module {
    source = "../modules/frontdoor"
  }

  plan_options {
    target = [aws_wafv2_web_acl.load_balancer, aws_wafv2_web_acl.main]
  }

  assert {
    condition = length([for rule in aws_wafv2_web_acl.load_balancer.rule : rule if rule.name == "allow-detectify-scanner"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 3 && length(rule.action[0].allow) == 1 &&
      rule.statement[0].ip_set_reference_statement[0].ip_set_forwarded_ip_config == tolist([{
        header_name       = "X-Forwarded-For"
        position          = "LAST"
        fallback_behavior = "NO_MATCH"
      }])
      if rule.name == "allow-detectify-scanner"
    ])
    error_message = "NFT must allow scanner IPs using the last X-Forwarded-For address with NO_MATCH fallback after origin validation."
  }

  assert {
    condition = length([for rule in aws_wafv2_web_acl.load_balancer.rule : rule if rule.name == "validate-cloudfront-header"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 1 && length(rule.action[0].block) == 1
      if rule.name == "validate-cloudfront-header"
    ])
    error_message = "NFT must validate the CloudFront origin header before allowing forwarded scanner IPs."
  }

  assert {
    condition = length([for rule in aws_wafv2_web_acl.load_balancer.rule : rule if rule.name == "block-simulator-config"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 0
      if rule.name == "block-simulator-config"
      ]) && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority > 3
      if length(rule.statement[0].managed_rule_group_statement) > 0
    ])
    error_message = "The simulator config block must remain first and managed rules must follow the scanner Allow."
  }

  assert {
    condition = (length([for rule in aws_wafv2_web_acl.main.rule : rule if rule.name == "allow-detectify-scanner"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.main.rule :
      rule.priority == 1 && length(rule.action[0].allow) == 1 &&
      length(rule.statement[0].ip_set_reference_statement[0].ip_set_forwarded_ip_config) == 0
      if rule.name == "allow-detectify-scanner"
      ]) && toset(aws_wafv2_ip_set.detectify_ips_regional.addresses) == toset(var.detectify_ips) &&
    toset(aws_wafv2_ip_set.detectify_ips.addresses) == toset(var.detectify_ips))
    error_message = "CloudFront must keep matching the connecting viewer and both scanner IP sets must retain their configured addresses."
  }
}

run "integration_scanner_behavior_unchanged" {
  command = plan

  providers = {
    aws           = aws
    aws.us-east-1 = aws
    random        = random
  }

  module {
    source = "../modules/frontdoor"
  }

  variables {
    environment_name = "integration"
    simulator_host   = null
  }

  plan_options {
    target = [aws_wafv2_web_acl.load_balancer]
  }

  assert {
    condition = length([for rule in aws_wafv2_web_acl.load_balancer.rule : rule if rule.name == "allow-detectify-scanner"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 1 && length(rule.action[0].allow) == 1 &&
      length(rule.statement[0].ip_set_reference_statement[0].ip_set_forwarded_ip_config) == 0
      if rule.name == "allow-detectify-scanner"
      ]) && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 3
      if rule.name == "validate-cloudfront-header"
    ])
    error_message = "Integration must retain source-IP scanner matching and its existing rule priorities."
  }
}

run "test_scanner_behavior_unchanged" {
  command = plan

  providers = {
    aws           = aws
    aws.us-east-1 = aws
    random        = random
  }

  module {
    source = "../modules/frontdoor"
  }

  variables {
    environment_name = "test"
    simulator_host   = null
  }

  plan_options {
    target = [aws_wafv2_web_acl.load_balancer]
  }

  assert {
    condition = length([for rule in aws_wafv2_web_acl.load_balancer.rule : rule if rule.name == "allow-detectify-scanner"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 1 && length(rule.action[0].allow) == 1 &&
      length(rule.statement[0].ip_set_reference_statement[0].ip_set_forwarded_ip_config) == 0
      if rule.name == "allow-detectify-scanner"
      ]) && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 3
      if rule.name == "validate-cloudfront-header"
    ])
    error_message = "Test must retain source-IP scanner matching and its existing rule priorities."
  }
}

run "production_scanner_behavior_unchanged" {
  command = plan

  providers = {
    aws           = aws
    aws.us-east-1 = aws
    random        = random
  }

  module {
    source = "../modules/frontdoor"
  }

  variables {
    environment_name = "production"
    simulator_host   = null
  }

  plan_options {
    target = [aws_wafv2_web_acl.load_balancer]
  }

  assert {
    condition = length([for rule in aws_wafv2_web_acl.load_balancer.rule : rule if rule.name == "allow-detectify-scanner"]) == 1 && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 1 && length(rule.action[0].allow) == 1 &&
      length(rule.statement[0].ip_set_reference_statement[0].ip_set_forwarded_ip_config) == 0
      if rule.name == "allow-detectify-scanner"
      ]) && alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.priority == 3
      if rule.name == "validate-cloudfront-header"
    ])
    error_message = "Production must retain source-IP scanner matching and its existing rule priorities."
  }
}

run "nft_without_scanner_ips_has_no_scanner_exception" {
  command = plan

  providers = {
    aws           = aws
    aws.us-east-1 = aws
    random        = random
  }

  module {
    source = "../modules/frontdoor"
  }

  variables {
    detectify_ips = []
  }

  plan_options {
    target = [aws_wafv2_web_acl.load_balancer]
  }

  assert {
    condition = alltrue([
      for rule in aws_wafv2_web_acl.load_balancer.rule :
      rule.name != "allow-detectify-scanner"
    ])
    error_message = "No scanner exception should be generated when no scanner IPs are configured."
  }
}
