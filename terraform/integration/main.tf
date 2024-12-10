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

locals {
  environment_name = "integration"
  multi_az         = false
  application_port = 8080
}

module "networking" {
  source                       = "../modules/networking"
  vpc_cidr_block               = "10.1.0.0/16"
  environment_name             = local.environment_name
  number_of_availability_zones = 2
  number_of_isolated_subnets   = local.multi_az ? 2 : 1
  integration_domains = [
    "oidc.integration.account.gov.uk",
    "api.os.uk",
    "api.notifications.service.gov.uk",
    "publicapi.payments.service.gov.uk"
  ]
}

module "frontdoor" {
  source = "../modules/frontdoor"

  ssl_certs_created         = var.ssl_certs_created
  environment_name          = local.environment_name
  public_subnet_ids         = module.networking.public_subnet[*].id
  vpc_id                    = module.networking.vpc.id
  application_port          = local.application_port
  cloudfront_domain_name    = "prsdb.communities.gov.uk"
  load_balancer_domain_name = "alb.prsdb.communities.gov.uk"
}

