#############################################
# IAM Identity Center Module
# Purpose: Centralized identity + SSO
# Note: Full Entra ID integration requires
#       UI configuration. This sets up the
#       permission sets and assignments.
#############################################

# Data source: Get Identity Center instance
data "aws_ssoadmin_instances" "main" {}

locals {
  identity_center_instance_arn  = data.aws_ssoadmin_instances.main.arns[0]
  identity_center_store_id      = data.aws_ssoadmin_instances.main.identity_store_ids[0]
}

# Permission Set: Administrator
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "${var.name_prefix}-admin"
  instance_arn     = local.identity_center_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

# Attach AdministratorAccess to Admin permission set
resource "aws_ssoadmin_managed_policy_attachment" "admin_policy" {
  instance_arn       = local.identity_center_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

# Permission Set: Developer (read/write to workload resources, no security changes)
resource "aws_ssoadmin_permission_set" "developer" {
  name             = "${var.name_prefix}-developer"
  instance_arn     = local.identity_center_instance_arn
  session_duration = "PT4H"

  tags = var.tags
}

# Inline policy for Developer permission set
resource "aws_ssoadmin_permission_set_inline_policy" "developer_policy" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.developer.arn
  inline_policy      = data.aws_iam_policy_document.developer_permissions.json
}

data "aws_iam_policy_document" "developer_permissions" {
  # Allow most AWS service operations except security-critical ones
  statement {
    sid    = "DenySecurityChanges"
    effect = "Deny"
    actions = [
      "iam:*",
      "organizations:*",
      "cloudtrail:*",
      "securityhub:*",
      "guardduty:*",
      "config:*",
      "kms:ScheduleKeyDeletion",
      "s3:DeleteBucket"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEC2AndNetworking"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "rds:*",
      "dynamodb:*",
      "s3:GetObject",
      "s3:PutObject",
      "lambda:*",
      "apigateway:*",
      "logs:*"
    ]
    resources = ["*"]
  }
}

# Permission Set: SecurityLead (read-only + Security Hub/GuardDuty access)
resource "aws_ssoadmin_permission_set" "security_lead" {
  name             = "${var.name_prefix}-security-lead"
  instance_arn     = local.identity_center_instance_arn
  session_duration = "PT8H"

  tags = var.tags
}

# Inline policy for SecurityLead permission set
resource "aws_ssoadmin_permission_set_inline_policy" "security_lead_policy" {
  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.security_lead.arn
  inline_policy      = data.aws_iam_policy_document.security_lead_permissions.json
}

data "aws_iam_policy_document" "security_lead_permissions" {
  statement {
    sid    = "ReadOnlyAccess"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "s3:Get*",
      "s3:List*",
      "rds:Describe*",
      "dynamodb:Describe*",
      "logs:Describe*",
      "logs:Get*",
      "logs:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecurityServices"
    effect = "Allow"
    actions = [
      "securityhub:*",
      "guardduty:Get*",
      "guardduty:List*",
      "config:Describe*",
      "config:Get*",
      "config:List*"
    ]
    resources = ["*"]
  }
}

# CloudTrail for SSO activity (audit trail)
resource "aws_cloudwatch_log_group" "identity_center_activity" {
  name              = "/aws/identity-center/${var.name_prefix}"
  retention_in_days = var.cloudwatch_retention_days

  tags = var.tags
}

# Output instructions for manual Entra ID setup
locals {
  entra_id_setup_instructions = <<-EOT
    # IAM Identity Center — Entra ID Integration Instructions
    
    1. In AWS Entra ID:
       - Create an enterprise application for AWS IAM Identity Center
       - Configure SAML SSO with endpoint:
         https://portal.sso.${var.aws_region}.amazonaws.com/saml
       
    2. In AWS Console (Identity Center):
       - Go to Settings → Identity source
       - Select "External identity provider"
       - Upload the SAML metadata from Entra ID
       - Test SAML configuration
    
    3. Create users/groups in Identity Center:
       - Map to corresponding Entra ID users
       - Assign permission sets
       - Configure MFA requirements
  EOT
}
