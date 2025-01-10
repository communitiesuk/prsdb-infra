terraform {
  required_version = "~>1.9.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }

  backend "s3" {
    bucket         = "prsdb-tfstate-integration"
    dynamodb_table = "tfstate-lock-integration"
    encrypt        = true
    key            = "prsdb-infra-integration-task-definition"
    region         = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
}

data "aws_iam_role" "ecs_task_execution" {
  name = "integration-ecs-task-execution"
}

data "aws_iam_role" "webapp_ecs_task" {
  name = "integration-webapp-ecs-task"
}

locals {
  # TODO: Get non-secret computed environment variables from SSM datasources
  environment = [
    {
      name  = "ENVIRONMENT_NAME"
      value = "integration"
    },
  ]
  # TODO: Get secrets from secrets manager datasources
  secrets = []
}

module "webapp_ecs_task_definition" {
  source                      = "../../modules/ecs_task"
  environment_name            = "integration"
  container_image             = var.image_name
  container_port              = 8080
  ecs_task_execution_role_arn = data.aws_iam_role.ecs_task_execution.arn
  ecs_task_role_arn           = data.aws_iam_role.webapp_ecs_task.arn
  task_cpu                    = 0
  task_memory                 = 0
  task_name                   = "prsdb-webapp"
  #   TODO: Add data sources for secrets once they're created + environment variables
}