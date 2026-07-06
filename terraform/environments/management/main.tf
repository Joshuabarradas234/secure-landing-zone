#############################################
# Management Account Configuration
# Purpose: Create organizational structure
#          with OUs and SCPs
#############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state
  # backend "s3" {
  #   bucket         = "REPLACE_ME-tfstate"
  #   key            = "landing-zone/management/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "REPLACE_ME-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
      Component   = "landing-zone-management"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

#############################################
# Organizations Module
#############################################

module "organizations" {
  source = "../../modules/organizations"

  name_prefix              = local.name_prefix
  management_account_id    = data.aws_caller_identity.current.account_id
  terraform_external_id    = var.terraform_external_id
  tags                     = local.common_tags
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
