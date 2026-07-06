#############################################
# Workload Base Environment (VPC Template)
# Purpose: Template for deploying workload VPCs
#          in dev, staging, or production accounts
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
  #   key            = "landing-zone/workload-base/terraform.tfstate"
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
      Component   = "landing-zone-workload"
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
# Networking Module (VPC + Subnets + NAT)
#############################################

module "networking" {
  source = "../../modules/networking"

  name_prefix               = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_subnet_cidrs     = var.private_subnet_cidrs
  availability_zones       = data.aws_availability_zones.available.names
  cloudwatch_retention_days = var.cloudwatch_retention_days
  tags                     = local.common_tags
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
