terraform {
  required_version = "~>1.9.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.24"
    }
    random = {
      version = "~>3.5"
      source  = "hashicorp/random"
    }
  }
}
