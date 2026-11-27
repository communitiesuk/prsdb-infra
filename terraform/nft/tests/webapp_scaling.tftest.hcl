mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}
mock_provider "aws" {
  alias = "us-east-1"
}
mock_provider "aws" {
  alias = "eu-west-1"
}
mock_provider "random" {}

variables {
  critical_alarm_email_address     = "critical@example.com"
  non_critical_alarm_email_address = "noncritical@example.com"
}

override_module {
  target = module.redis
  outputs = {
    redis_cluster_ids       = ["nft-redis-001"]
    redis_security_group_id = "sg-12345678"
  }
}

override_module {
  target = module.frontdoor
  outputs = {
    load_balancer = {
      name                         = "nft"
      arn                          = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:loadbalancer/app/nft/1234567890123456"
      arn_suffix                   = "app/nft/1234567890123456"
      dns_name                     = "nft.example.com"
      listener_arn                 = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:listener/app/nft/1234567890123456/1234567890123456"
      security_group_id            = "sg-12345678"
      simulator_security_group_id  = "sg-23456789"
      simulator_security_group_arn = "arn:aws:ec2:eu-west-2:123456789012:security-group/sg-23456789"
      target_group_arn             = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/nft/1234567890123456"
      target_group_arn_suffix      = "targetgroup/nft/1234567890123456"
    }
    performance_runner_cloudfront_ip_set_arn = "arn:aws:wafv2:us-east-1:123456789012:global/ipset/test/12345678-1234-1234-1234-123456789012"
    performance_runner_regional_ip_set_arn   = "arn:aws:wafv2:eu-west-2:123456789012:regional/ipset/test/12345678-1234-1234-1234-123456789012"
  }
}

run "custom_capacity_and_cpu" {
  command = plan

  variables {
    webapp_scaling_min_capacity = 3
    webapp_scaling_max_capacity = 12
    webapp_scaling_cpu_target   = 70
  }

  assert {
    condition = (aws_appautoscaling_target.webapp[0].min_capacity == 3 &&
      aws_appautoscaling_target.webapp[0].max_capacity == 12 &&
      aws_appautoscaling_policy.webapp_cpu[0].target_tracking_scaling_policy_configuration[0].target_value == 70 &&
      aws_appautoscaling_policy.webapp_cpu[0].target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60 &&
    aws_appautoscaling_policy.webapp_cpu[0].target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 300)
    error_message = "NFT must use the configured capacity and CPU target with the expected cooldowns."
  }
}

run "invalid_capacity_range" {
  command = plan

  variables {
    webapp_scaling_min_capacity = 5
    webapp_scaling_max_capacity = 4
  }

  expect_failures = [aws_appautoscaling_target.webapp]
}

run "disabled_without_task_definition" {
  command = plan

  variables {
    task_definition_created = false
  }

  assert {
    condition     = length(aws_appautoscaling_target.webapp) == 0 && length(aws_appautoscaling_policy.webapp_cpu) == 0
    error_message = "Scaling must not be created before the task definition."
  }
}
