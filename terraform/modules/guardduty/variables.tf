variable "name_prefix" {
  description = "Naming prefix for all resources"
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
