terraform {
  required_version = "~>1.9.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }

  backend "s3" {
    bucket         = "prsdb-tfstate-production"
    dynamodb_table = "tfstate-lock-production"
    encrypt        = true
    key            = "prsdb-infra-production"
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
  environment_name = "production"
  multi_az         = false
  application_port = 8080
  database_port    = 5432
  redis_port       = 6379

  app_host                  = "register-home-to-rent.communities.gov.uk"
  search_landlord_host      = "search-landlord-home-information.communities.gov.uk"
  load_balancer_domain_name = "lb.register-home-to-rent.communities.gov.uk"

  cloudwatch_log_expiration_days = 90
  database_allocated_storage     = 50

  ip_allowlist = var.ip_restrictions_on ? [
    # Softwire
    "31.221.86.178/32",
    "167.98.33.82/32",
    "87.224.105.250/32",
    "87.224.116.242/32",
    "45.150.142.210/32",
    # Made Tech
    "79.173.131.202/32",
    "172.166.224.214/32",
    # MHCLG
    "4.158.35.41/32",
    # Detectify
    "52.17.9.21/32",
    "52.17.98.131/32",
    # Detectify N. Virginia
    "107.20.158.220/32",
    "3.234.180.95/32",
    "34.234.177.119/32",
    # Detectify Mumbai
    "13.126.5.12/32",
    "3.7.157.159/32",
    "3.7.173.162/32",
  ] : []
}

module "networking" {
  source                       = "../modules/networking"
  vpc_cidr_block               = "10.1.0.0/16"
  environment_name             = local.environment_name
  number_of_availability_zones = 2
  number_of_isolated_subnets   = 2 # RDS requires there to be 2 subnets in different AZs even when multi-AZ is disabled

  vpc_flow_cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
}

module "frontdoor" {
  source = "../modules/frontdoor"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  ssl_certs_created = var.ssl_certs_created
  environment_name  = local.environment_name
  public_subnet_ids = module.networking.public_subnets[*].id
  vpc_id            = module.networking.vpc.id
  application_port  = local.application_port
  cloudfront_domain_names = [
    local.app_host,
    local.search_landlord_host,
  ]
  load_balancer_domain_name      = local.load_balancer_domain_name
  cloudfront_certificate_arn     = module.certificates.cloudfront_certificate_arn
  load_balancer_certificate_arn  = module.certificates.load_balancer_certificate_arn
  ip_allowlist                   = local.ip_allowlist
  cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
  use_aws_shield_advanced        = true
  maintenance_mode_on = var.maintenance_mode_on
}

module "certificates" {
  source = "../modules/certificates"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  cloudfront_domain_name    = local.app_host
  load_balancer_domain_name = local.load_balancer_domain_name
  cloudfront_additional_names = [
    local.search_landlord_host,
  ]
  load_balancer_additional_names = [
    "lb.search-landlord-home-information.communities.gov.uk",
  ]
}

module "ecr" {
  source = "../modules/ecr"

  environment_name      = local.environment_name
  image_retention_count = 10
}

module "github_actions_access" {
  source = "../modules/github_actions_access"

  environment_name               = local.environment_name
  push_ecr_image_policy_arn      = module.ecr.push_ecr_image_policy_arn
  db_username_ssm_parameter_arn  = module.database.database_username_ssm_parameter_arn
  db_url_ssm_parameter_arn       = module.database.database_url_ssm_parameter_arn
  db_password_secret_arn         = module.secrets.database_password_secret_arn
  secrets_kms_key_arn            = module.secrets.secrets_kms_key_arn
  bastion_host_arns              = module.bastion.bastion_instance_arns
  ecs_service_arn                = var.task_definition_created ? module.ecs_service[0].ecs_service_arn : ""
  ecs_task_execution_role_arn    = module.ecr.ecs_task_execution_role_arn
  webapp_ecs_task_role_arn       = module.ecr.webapp_ecs_task_role_arn
  task_definition_created        = var.task_definition_created
  ecr_describe_images_policy_arn = module.ecr.describe_ecr_images_policy_arn
}

module "secrets" {
  source = "../modules/secrets"

  environment_name               = local.environment_name
  webapp_task_execution_role_arn = module.ecr.ecs_task_execution_role_arn
  webapp_task_execution_role_id  = module.ecr.ecs_task_execution_role_id
}

module "parameters" {
  source = "../modules/ssm"

  environment_name         = local.environment_name
  landlord_base_url        = local.app_host
  local_authority_base_url = local.search_landlord_host
}

module "bastion" {
  source = "../modules/bastion"

  bastion_subnet_ids = module.networking.private_subnets[*].id
  environment_name   = local.environment_name
  main_vpc_id        = module.networking.vpc.id
  vpc_cidr_block     = module.networking.vpc.cidr_block

  bastion_ssm_patch_cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
}

module "database" {
  source = "../modules/rds"

  environment_name                = local.environment_name
  database_password               = module.secrets.database_password.result
  database_port                   = local.database_port
  allocated_storage               = local.database_allocated_storage
  backup_retention_period         = 7
  db_subnet_group_name            = module.networking.db_subnet_group_name
  instance_class                  = "db.t4g.small"
  multi_az                        = local.multi_az
  vpc_id                          = module.networking.vpc.id
  webapp_task_execution_role_name = module.ecr.webapp_ecs_task_role_name
  bastion_group_id                = module.bastion.security_group_id
}

module "redis" {
  source = "../modules/elasticache"

  environment_name               = local.environment_name
  highly_available               = false
  node_type                      = "cache.t4g.micro"
  redis_password                 = module.secrets.redis_password.result
  redis_port                     = local.redis_port
  redis_subnet_group_name        = module.networking.redis_subnet_group_name
  snapshot_retention_limit       = 7
  vpc_id                         = module.networking.vpc.id
  cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
}

module "ecs_service" {
  count  = var.task_definition_created ? 1 : 0
  source = "../modules/ecs_service"

  environment_name          = local.environment_name
  webapp_task_desired_count = 1
  application_port          = local.application_port
  database_port             = local.database_port
  redis_port                = local.redis_port
  lb_target_group_arn       = module.frontdoor.load_balancer.target_group_arn
  lb_security_group_id      = module.frontdoor.load_balancer.security_group_id
  db_security_group_id      = module.database.rds_security_group_id
  redis_security_group_id   = module.redis.redis_security_group_id
  private_subnet_ids        = module.networking.private_subnets[*].id
  vpc_id                    = module.networking.vpc.id
}

module "file_upload" {
  count                           = var.task_definition_created ? 1 : 0
  source                          = "../modules/file_upload"
  environment_name                = local.environment_name
  webapp_task_execution_role_name = module.ecr.webapp_ecs_task_role_name
  ecs_cluster_arn                 = module.ecs_service[0].ecs_cluster_arn
  private_subnet_ids              = module.networking.private_subnets[*].id
  ecs_security_group_ids          = module.ecs_service[0].ecs_security_group_ids
}

module "monitoring" {
  source = "../modules/monitoring"

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  environment_name               = local.environment_name
  cloudwatch_log_expiration_days = local.cloudwatch_log_expiration_days
  alarm_email_address            = var.alarm_email_address
  alb_name                       = module.frontdoor.load_balancer.name
  alb_arn_suffix                 = module.frontdoor.load_balancer.arn_suffix
  alb_target_group_arn_suffix    = module.frontdoor.load_balancer.target_group_arn_suffix
  ecs_cluster_name               = var.task_definition_created ? module.ecs_service[0].ecs_cluster_name : ""
  ecs_service_name               = var.task_definition_created ? module.ecs_service[0].ecs_service_name : ""
  elasticache_cluster_ids        = toset(module.redis.redis_cluster_ids)
  database_allocated_storage     = local.database_allocated_storage
  database_identifier            = module.database.database_identifier
  waf_acl_name                   = module.frontdoor.waf_acl_name
}
