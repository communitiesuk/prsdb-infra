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
    key            = "prsdb-infra-integration"
    region         = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

locals {
  environment_name = "integration"
  multi_az         = false
  application_port = 8080
  database_port    = 5432
  redis_port       = 6379

  app_host                  = "${local.environment_name}.register-home-to-rent.test.communities.gov.uk"
  load_balancer_domain_name = "${local.environment_name}.lb.register-home-to-rent.test.communities.gov.uk"
}

module "networking" {
  source                       = "../modules/networking"
  vpc_cidr_block               = "10.1.0.0/16"
  environment_name             = local.environment_name
  number_of_availability_zones = 2
  number_of_isolated_subnets   = 2 # RDS requires there to be 2 subnets in different AZs even when multi-AZ is disabled
  integration_domains = [
    "oidc.integration.account.gov.uk",
    "api.os.uk",
    "api.notifications.service.gov.uk",
    "publicapi.payments.service.gov.uk"
  ]
}

module "frontdoor" {
  source = "../modules/frontdoor"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  ssl_certs_created             = var.ssl_certs_created
  environment_name              = local.environment_name
  public_subnet_ids             = module.networking.public_subnets[*].id
  vpc_id                        = module.networking.vpc.id
  application_port              = local.application_port
  cloudfront_domain_name        = "${local.environment_name}.register-home-to-rent.test.communities.gov.uk"
  load_balancer_domain_name     = "${local.environment_name}.lb.register-home-to-rent.test.communities.gov.uk"
  cloudfront_certificate_arn    = module.certificates.cloudfront_certificate_arn
  load_balancer_certificate_arn = module.certificates.load_balancer_certificate_arn
  # TODO: Add Softwire and MHCLG IPs
  ip_allowlist = []
}

module "certificates" {
  source = "../modules/certificates"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  cloudfront_domain_name    = local.app_host
  load_balancer_domain_name = local.load_balancer_domain_name
  cloudfront_additional_names = [
    "${local.environment_name}.search-landlord-home-information.test.communities.gov.uk",
    "${local.environment_name}.check-home-to-rent-registration.test.communities.gov.uk"
  ]
  load_balancer_additional_names = [
    "${local.environment_name}.lb.search-landlord-home-information.test.communities.gov.uk",
    "${local.environment_name}.lb.check-home-to-rent-registration.test.communities.gov.uk"
  ]
}

module "ecr" {
  source = "../modules/ecr"

  environment_name      = local.environment_name
  image_retention_count = 3
}

module "github_actions_access" {
  source = "../modules/github_actions_access"

  environment_name          = local.environment_name
  push_ecr_image_policy_arn = module.ecr.push_ecr_image_policy_arn
}

module "secrets" {
  source = "../modules/secrets"

  environment_name               = local.environment_name
  webapp_task_execution_role_arn = module.ecr.ecs_task_execution_role_arn
  webapp_task_execution_role_id  = module.ecr.ecs_task_execution_role_id
}

module "parameters" {
  source = "../modules/ssm"

  environment_name = local.environment_name
}

module "database" {
  source = "../modules/rds"

  environment_name                = local.environment_name
  database_password               = module.secrets.database_password.result
  database_port                   = local.database_port
  allocated_storage               = 50
  backup_retention_period         = 7
  db_subnet_group_name            = module.networking.db_subnet_group_name
  instance_class                  = "db.t4g.small"
  multi_az                        = local.multi_az
  vpc_id                          = module.networking.vpc.id
  webapp_task_execution_role_name = module.ecr.webapp_ecs_task_role_name
}

module "redis" {
  source = "../modules/elasticache"

  environment_name         = local.environment_name
  highly_available         = false
  node_type                = "cache.t4g.micro"
  redis_password           = module.secrets.redis_password.result
  redis_port               = local.redis_port
  redis_subnet_group_name  = module.networking.redis_subnet_group_name
  snapshot_retention_limit = 7
  vpc_id                   = module.networking.vpc.id
}