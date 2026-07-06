variable "name_prefix" {
  description = "Naming prefix for all resources"
  type        = string
}

variable "management_account_id" {
  description = "AWS Account ID of the management account"
  type        = string
}

variable "terraform_external_id" {
  description = "External ID for cross-account Terraform role assumption"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
