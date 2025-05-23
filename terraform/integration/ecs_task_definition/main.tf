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

locals {
  environment_name = "integration"
}

provider "aws" {
  region = "eu-west-2"
}

locals {
  environment_variables = [
    {
      name  = "ENVIRONMENT_NAME"
      value = local.environment_name
    },
    {
      name  = "ONE_LOGIN_PUBLIC_KEY"
      value = data.aws_ssm_parameter.one_login_public_key.value
    },
    {
      name  = "ONE_LOGIN_CLIENT_ID"
      value = data.aws_ssm_parameter.one_login_client_id.value
    },
    {
      name  = "ONE_LOGIN_ISSUER_URL"
      value = data.aws_ssm_parameter.one_login_issuer_url.value
    },
    {
      name  = "RDS_URL"
      value = "jdbc:postgresql://${data.aws_ssm_parameter.database_url.value}"
    },
    {
      name  = "RDS_USERNAME"
      value = data.aws_ssm_parameter.database_username.value
    },
    {
      name  = "ELASTICACHE_URL"
      value = data.aws_ssm_parameter.redis_url.value
    },
    {
      name  = "ELASTICACHE_PORT"
      value = data.aws_ssm_parameter.redis_port.value
    },
    {
      name  = "AWS_QUARANTINE_BUCKET"
      value = data.aws_ssm_parameter.quarantine_bucket.value
    },
    {
      name  = "EPC_REGISTER_CLIENT_ID"
      value = data.aws_ssm_parameter.epc_client_id.value
    },
    {
      name  = "EPC_REGISTER_TOKEN_URI"
      value = data.aws_ssm_parameter.epc_token_uri.value
    },
    {
      name  = "EPC_REGISTER_BASE_URL"
      value = data.aws_ssm_parameter.epc_base_url.value
    },
  ]
  secrets = [
    {
      name      = "RDS_PASSWORD"
      valueFrom = data.aws_secretsmanager_secret.database_password.arn
    },
    {
      name      = "ELASTICACHE_PASSWORD"
      valueFrom = data.aws_secretsmanager_secret.redis_password.arn
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
    {
      name      = "EPC_REGISTER_CLIENT_SECRET"
      valueFrom = data.aws_secretsmanager_secret.epc_client_secret.arn
    },
  ]
}

module "webapp_ecs_task_definition" {
  source                      = "../../modules/ecs_task"
  environment_name            = local.environment_name
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