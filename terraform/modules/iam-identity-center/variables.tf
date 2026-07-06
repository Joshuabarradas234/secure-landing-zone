variable "name_prefix" {
  description = "Naming prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Identity Center configuration"
  type        = string
}

variable "cloudwatch_retention_days" {
  description = "CloudWatch Log Group retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
