output "identity_center_instance_arn" {
  description = "ARN of the Identity Center instance"
  value       = local.identity_center_instance_arn
}

output "identity_center_store_id" {
  description = "ID of the Identity Center store"
  value       = local.identity_center_store_id
}

output "admin_permission_set_arn" {
  description = "ARN of the Admin permission set"
  value       = aws_ssoadmin_permission_set.admin.arn
}

output "developer_permission_set_arn" {
  description = "ARN of the Developer permission set"
  value       = aws_ssoadmin_permission_set.developer.arn
}

output "security_lead_permission_set_arn" {
  description = "ARN of the SecurityLead permission set"
  value       = aws_ssoadmin_permission_set.security_lead.arn
}

output "entra_id_setup_instructions" {
  description = "Instructions for configuring Entra ID federation"
  value       = local.entra_id_setup_instructions
  sensitive   = false
}
