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

data "aws_secretsmanager_secret" "database_password" {
  name = "tf-integration-prsdb-database-password"
}

data "aws_secretsmanager_secret" "one_login_private_key" {
  name = "tf-integration-one-login-private-key"
}

data "aws_secretsmanager_secret" "notify_api_key" {
  name = "tf-integration-notify-api-key"
}

data "aws_secretsmanager_secret" "os_places_api_key" {
  name = "tf-integration-os-places-api-key"
}

locals {
  # TODO: Get non-secret computed environment variables from SSM datasources
  environment_variables = [
    {
      name  = "ENVIRONMENT_NAME"
      value = "integration"
    },
  ]
  secrets = [
    {
      name      = "RDS_PASSWORD"
      valueFrom = data.aws_secretsmanager_secret.database_password.arn
    },
    {
      name      = "ONE_LOGIN_PRIVATE_KEY"
      valueFrom = data.aws_secretsmanager_secret.one_login_private_key.arn
    },
    {
      name      = "EMAILNOTIFICATIONS_APIKEY"
      valueFrom = data.aws_secretsmanager_secret.notify_api_key.arn
    },
    {
      name      = "OS_PLACES_API_KEY"
      valueFrom = data.aws_secretsmanager_secret.os_places_api_key.arn
    },
  ]
}

module "webapp_ecs_task_definition" {
  source                      = "../../modules/ecs_task"
  environment_name            = "integration"
  container_image             = var.image_name
  container_port              = 8080
  ecs_task_execution_role_arn = data.aws_iam_role.ecs_task_execution.arn
  ecs_task_role_arn           = data.aws_iam_role.webapp_ecs_task.arn
  # TODO: consider what our requirements are for the instance
  task_cpu              = 512
  task_memory           = 1024
  task_name             = "prsdb-webapp"
  environment_variables = local.environment_variables
  secrets               = local.secrets
}