output "organization_arn" {
  description = "ARN of the AWS Organization"
  value       = data.aws_organizations_organization.main.arn
}

output "organization_id" {
  description = "ID of the AWS Organization"
  value       = data.aws_organizations_organization.main.id
}

output "root_ou_id" {
  description = "Root OU ID"
  value       = data.aws_organizations_organization_roots.roots.roots[0].id
}

output "security_ou_id" {
  description = "Security OU ID"
  value       = aws_organizations_organizational_unit.security.id
}

output "shared_services_ou_id" {
  description = "Shared Services OU ID"
  value       = aws_organizations_organizational_unit.shared_services.id
}

output "workloads_ou_id" {
  description = "Workloads OU ID"
  value       = aws_organizations_organizational_unit.workloads.id
}

output "terraform_cross_account_role_arn" {
  description = "ARN of the cross-account role for Terraform"
  value       = aws_iam_role.terraform_cross_account.arn
}

output "scp_ids" {
  description = "IDs of created Service Control Policies"
  value = {
    deny_cloudtrail_disabled    = aws_organizations_policy.deny_disable_cloudtrail.id
    require_s3_encryption       = aws_organizations_policy.require_s3_encryption.id
    protect_security_services   = aws_organizations_policy.protect_security_services.id
  }
}
