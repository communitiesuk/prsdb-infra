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
  multi_az = false
}

module "networking" {
  source                     = "../modules/networking"
  vpc_cidr_block             = "10.1.0.0/16"
  environment_name           = local.environment_name
  number_of_isolated_subnets = local.multi_az ? 2 : 1
  integration_domains = [
    "oidc.integration.account.gov.uk",
    "api.os.uk",
    "api.notifications.service.gov.uk",
    "publicapi.payments.service.gov.uk"
  ]
}

