mock_provider "aws" {}

variables {
  environment_name                = "nft"
  webapp_task_desired_count       = 2
  async_worker_task_desired_count = 2
  application_port                = 8080
  database_port                   = 5432
  redis_port                      = 6379
  lb_target_group_arn             = "arn:aws:elasticloadbalancing:eu-west-2:123456789012:targetgroup/test/1234567890123456"
  lb_security_group_id            = "sg-12345678"
  db_security_group_id            = "sg-23456789"
  redis_security_group_id         = "sg-34567890"
  private_subnet_ids              = ["subnet-12345678"]
  vpc_id                          = "vpc-12345678"
}

run "initial_services" {
  command = apply
}

run "only_worker_desired_count_is_managed" {
  command = plan

  variables {
    webapp_task_desired_count       = 4
    async_worker_task_desired_count = 3
  }

  assert {
    condition     = aws_ecs_service.webapp.desired_count == 2
    error_message = "Terraform must not reset the webapp desired count."
  }

  assert {
    condition     = module.async_worker_service.name == "nft-async-worker"
    error_message = "The worker service must remain present."
  }
}
