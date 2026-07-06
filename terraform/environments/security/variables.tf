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

variable "member_account_ids" {
  description = "List of member AWS account IDs to aggregate findings from"
  type        = list(string)
  default     = []
  # Example: ["123456789012", "210987654321"]
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch Log Group retention in days"
  type        = number
  default     = 30
}

variable "enable_default_standards" {
  description = "Enable default Security Hub standards"
  type        = bool
  default     = true
}

variable "enable_pci_dss" {
  description = "Enable PCI DSS compliance standard (adds cost)"
  type        = bool
  default     = false
}
