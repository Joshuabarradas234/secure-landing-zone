variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "secure-multi-account-landing-zone"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Owner/team name"
  type        = string
  default     = "platform-engineering"
}

variable "terraform_external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  sensitive   = true
  default     = "terraform-landing-zone"
}
