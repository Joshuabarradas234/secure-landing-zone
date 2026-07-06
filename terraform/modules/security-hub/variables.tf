variable "name_prefix" {
  description = "Naming prefix for all resources"
  type        = string
}

variable "member_account_ids" {
  description = "List of member AWS account IDs to aggregate findings from"
  type        = list(string)
  default     = []
}

variable "enable_default_standards" {
  description = "Enable default Security Hub standards"
  type        = bool
  default     = true
}

variable "enable_pci_dss" {
  description = "Enable PCI DSS compliance standard"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
