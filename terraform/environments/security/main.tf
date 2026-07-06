#############################################
# Security Account Configuration
# Purpose: Centralized logging, monitoring
#          Security Hub, GuardDuty
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
  #   key            = "landing-zone/security/terraform.tfstate"
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
      Component   = "landing-zone-security"
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
# Security Logging Module
#############################################

module "security_logging" {
  source = "../../modules/security-logging"

  name_prefix              = local.name_prefix
  cloudwatch_retention_days = var.cloudwatch_retention_days
  tags                     = local.common_tags
}

#############################################
# Security Hub Module
#############################################

module "security_hub" {
  source = "../../modules/security-hub"

  name_prefix              = local.name_prefix
  member_account_ids       = var.member_account_ids
  enable_default_standards = var.enable_default_standards
  enable_pci_dss          = var.enable_pci_dss
  tags                     = local.common_tags

  # Wait for Security Hub to initialize
  depends_on = [module.security_logging]
}

#############################################
# GuardDuty Module
#############################################

module "guardduty" {
  source = "../../modules/guardduty"

  name_prefix              = local.name_prefix
  cloudwatch_retention_days = var.cloudwatch_retention_days
  tags                     = local.common_tags
}

#############################################
# IAM Identity Center Module
#############################################

module "iam_identity_center" {
  source = "../../modules/iam-identity-center"

  name_prefix              = local.name_prefix
  aws_region              = var.aws_region
  cloudwatch_retention_days = var.cloudwatch_retention_days
  tags                     = local.common_tags
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
