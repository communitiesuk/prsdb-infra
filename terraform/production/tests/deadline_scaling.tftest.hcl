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
  task_definition_created          = false
  critical_alarm_email_address     = "critical@example.com"
  non_critical_alarm_email_address = "noncritical@example.com"
}

run "deadline_windows" {
  command = plan

  assert {
    condition = local.deadline_scaling_actions == {
      west_midlands-raise          = { date = "2027-03-13", time = "07:00:00", min_capacity = 6 }
      west_midlands-restore        = { date = "2027-03-15", time = "01:00:00", min_capacity = 2 }
      east_of_england-raise        = { date = "2027-04-13", time = "07:00:00", min_capacity = 6 }
      east_of_england-restore      = { date = "2027-04-15", time = "01:00:00", min_capacity = 2 }
      east_midlands-raise          = { date = "2027-05-13", time = "07:00:00", min_capacity = 6 }
      east_midlands-restore        = { date = "2027-05-15", time = "01:00:00", min_capacity = 2 }
      south_east-raise             = { date = "2027-06-13", time = "07:00:00", min_capacity = 6 }
      south_east-restore           = { date = "2027-06-15", time = "01:00:00", min_capacity = 2 }
      yorkshire_and_humber-raise   = { date = "2027-07-13", time = "07:00:00", min_capacity = 6 }
      yorkshire_and_humber-restore = { date = "2027-07-15", time = "01:00:00", min_capacity = 2 }
      north_west-raise             = { date = "2027-08-13", time = "07:00:00", min_capacity = 6 }
      north_west-restore           = { date = "2027-08-15", time = "01:00:00", min_capacity = 2 }
      north_east-raise             = { date = "2027-09-13", time = "07:00:00", min_capacity = 6 }
      north_east-restore           = { date = "2027-09-15", time = "01:00:00", min_capacity = 2 }
      london-raise                 = { date = "2027-10-13", time = "07:00:00", min_capacity = 6 }
      london-restore               = { date = "2027-10-15", time = "01:00:00", min_capacity = 2 }
      south_west-raise             = { date = "2027-11-13", time = "07:00:00", min_capacity = 6 }
      south_west-restore           = { date = "2027-11-15", time = "01:00:00", min_capacity = 2 }
    }

    error_message = "Each registration deadline must have the correct raise and restore window."
  }
}

run "scheduled_actions" {
  command = plan

  variables {
    task_definition_created = true
  }

  override_module {
    target = module.redis
    outputs = {
      redis_cluster_ids       = ["production-redis-001"]
      redis_security_group_id = "sg-12345678"
    }
  }

  assert {
    condition = length(aws_appautoscaling_scheduled_action.deadline) == 18 && alltrue([
      for key, action in aws_appautoscaling_scheduled_action.deadline :
      action.timezone == "Europe/London" &&
      action.schedule == "at(${local.deadline_scaling_actions[key].date}T${local.deadline_scaling_actions[key].time})" &&
      tonumber(action.scalable_target_action[0].min_capacity) == local.deadline_scaling_actions[key].min_capacity &&
      tonumber(action.scalable_target_action[0].max_capacity) == 15
    ])
    error_message = "Each deadline must create a one-time London action with the expected capacity."
  }

  assert {
    condition = (aws_appautoscaling_target.webapp[0].min_capacity == 2 &&
      aws_appautoscaling_target.webapp[0].max_capacity == 15 &&
      aws_appautoscaling_policy.webapp_cpu[0].target_tracking_scaling_policy_configuration[0].target_value == 60 &&
      aws_appautoscaling_policy.webapp_cpu[0].target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60 &&
    aws_appautoscaling_policy.webapp_cpu[0].target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 300)
    error_message = "Production scaling must use the approved capacity, CPU target and cooldowns."
  }
}
