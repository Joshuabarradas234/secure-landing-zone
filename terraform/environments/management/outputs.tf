output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organizations.organization_id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = module.organizations.organization_arn
}

output "root_ou_id" {
  description = "Root OU ID"
  value       = module.organizations.root_ou_id
}

output "security_ou_id" {
  description = "Security OU ID"
  value       = module.organizations.security_ou_id
}

output "shared_services_ou_id" {
  description = "Shared Services OU ID"
  value       = module.organizations.shared_services_ou_id
}

output "workloads_ou_id" {
  description = "Workloads OU ID"
  value       = module.organizations.workloads_ou_id
}

output "terraform_cross_account_role_arn" {
  description = "ARN of cross-account role for Terraform"
  value       = module.organizations.terraform_cross_account_role_arn
}

output "scp_ids" {
  description = "IDs of applied Service Control Policies"
  value       = module.organizations.scp_ids
}
