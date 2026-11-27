mock_provider "aws" {}

variables {
  name                   = "nft-async-worker"
  cluster_arn            = "arn:aws:ecs:eu-west-2:123456789012:cluster/nft-app"
  task_definition_family = "prsdb-async-worker-nft"
  desired_count          = 2
  allow_exec             = false
  private_subnet_ids     = ["subnet-12345678"]
  security_group_ids     = ["sg-12345678"]
}

run "initial_worker" {
  command = apply
}

run "worker_count_changes" {
  command = plan

  variables {
    desired_count = 3
  }

  assert {
    condition     = aws_ecs_service.main.desired_count == 3
    error_message = "Terraform must continue managing the worker desired count."
  }
}
