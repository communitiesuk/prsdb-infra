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

  app_host                  = "integration.register-home-to-rent.test.communities.gov.uk"
  load_balancer_domain_name = "integration.lb.register-home-to-rent.test.communities.gov.uk"
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

  providers = {
    aws.us-east-1 = aws.us-east-1
  }

  ssl_certs_created             = var.ssl_certs_created
  environment_name              = local.environment_name
  public_subnet_ids             = module.networking.public_subnets[*].id
  vpc_id                        = module.networking.vpc.id
  application_port              = local.application_port
  cloudfront_domain_name        = "integration.register-home-to-rent.test.communities.gov.uk"
  load_balancer_domain_name     = "integration.lb.register-home-to-rent.test.communities.gov.uk"
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
    "integration.search-landlord-home-information.test.communities.gov.uk",
    "integration.check-home-to-rent-registration.test.communities.gov.uk"
  ]
  load_balancer_additional_names = [
    "integration.lb.search-landlord-home-information.test.communities.gov.uk",
    "integration.lb.check-home-to-rent-registration.test.communities.gov.uk"
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

