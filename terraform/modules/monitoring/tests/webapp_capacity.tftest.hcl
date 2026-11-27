mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
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

variables {
  environment_name                 = "nft"
  critical_alarm_email_address     = "critical@example.com"
  non_critical_alarm_email_address = "noncritical@example.com"
  cloudwatch_log_expiration_days   = 30
  ecs_cluster_name                 = "nft-app"
  ecs_service_name                 = "nft-app"
  database_identifier              = "nft-db"
  database_allocated_storage       = 20
  backup_replication_kms_key_arn   = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  elasticache_cluster_ids          = []
  alb_name                         = "nft"
  alb_arn_suffix                   = "app/nft/1234567890123456"
  alb_target_group_arn_suffix      = "targetgroup/nft/1234567890123456"
  webapp_ecs_task_role_name        = "nft-webapp"
  backup_vault_kms_key_arns        = ["arn:aws:kms:eu-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"]
  backup_role_arn                  = "arn:aws:iam::123456789012:role/prsdb-AWSBackup-role-nft"
  backed_up_s3_bucket_names        = ["prsdb-uploaded-files-nft"]
}

run "configured_minimum" {
  command = plan

  variables {
    webapp_scaling_min_capacity = 3
    webapp_scaling_max_capacity = 12
  }

  assert {
    condition = (aws_cloudwatch_metric_alarm.webapp_running_below_minimum[0].metric_name == "RunningTaskCount" &&
      aws_cloudwatch_metric_alarm.webapp_running_below_minimum[0].namespace == "ECS/ContainerInsights" &&
      aws_cloudwatch_metric_alarm.webapp_running_below_minimum[0].statistic == "Minimum" &&
      aws_cloudwatch_metric_alarm.webapp_running_below_minimum[0].comparison_operator == "LessThanThreshold" &&
      aws_cloudwatch_metric_alarm.webapp_running_below_minimum[0].threshold == 3 &&
      aws_cloudwatch_metric_alarm.webapp_running_below_minimum[0].dimensions == tomap({
        ClusterName = "nft-app"
        ServiceName = "nft-app"
    }))
    error_message = "The running-task alarm must use the configured minimum and service-level metric."
  }
}

run "no_autoscaling" {
  command = plan
  assert {
    condition     = length(aws_cloudwatch_metric_alarm.webapp_running_below_minimum) == 0 && length(aws_cloudwatch_metric_alarm.webapp_at_max_capacity) == 0
    error_message = "Scaling capacity alarms must be disabled when no bounds are configured."
  }
}
