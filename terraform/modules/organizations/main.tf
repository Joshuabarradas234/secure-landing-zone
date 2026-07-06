#############################################
# AWS Organizations Module
# Purpose: Create multi-account structure
#          with OUs and Service Control Policies
#############################################

# Enable AWS Organizations (only needed once)
data "aws_organizations_organization" "main" {}

# Define Organizational Units
# Root OU is created automatically by AWS
data "aws_organizations_organization_roots" "roots" {}

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = data.aws_organizations_organization_roots.roots.roots[0].id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "shared_services" {
  name      = "SharedServices"
  parent_id = data.aws_organizations_organization_roots.roots.roots[0].id

  tags = var.tags
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = data.aws_organizations_organization_roots.roots.roots[0].id

  tags = var.tags
}

#############################################
# Service Control Policies (SCPs)
# Applied at organization and OU levels
#############################################

# SCP: Prevent disabling CloudTrail
resource "aws_organizations_policy" "deny_disable_cloudtrail" {
  name            = "${var.name_prefix}-deny-disable-cloudtrail"
  description     = "Prevent disabling CloudTrail and modifying logging configuration"
  type            = "SERVICE_CONTROL_POLICY"
  content         = data.aws_iam_policy_document.deny_disable_cloudtrail.json
  tags            = var.tags
}

data "aws_iam_policy_document" "deny_disable_cloudtrail" {
  statement {
    sid    = "DenyDisableCloudTrail"
    effect = "Deny"
    actions = [
      "cloudtrail:DeleteTrail",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyS3DeleteCloudTrailLogs"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteBucket"
    ]
    resources = [
      "arn:aws:s3:::*cloudtrail*",
      "arn:aws:s3:::*cloudtrail*/*"
    ]
  }
}

# SCP: Enforce S3 encryption
resource "aws_organizations_policy" "require_s3_encryption" {
  name            = "${var.name_prefix}-require-s3-encryption"
  description     = "Require S3 buckets to have encryption enabled"
  type            = "SERVICE_CONTROL_POLICY"
  content         = data.aws_iam_policy_document.require_s3_encryption.json
  tags            = var.tags
}

data "aws_iam_policy_document" "require_s3_encryption" {
  statement {
    sid    = "DenyUnencryptedS3"
    effect = "Deny"
    actions = [
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::*/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256", "aws:kms"]
    }
  }

  statement {
    sid    = "DenyCreateUnencryptedBucket"
    effect = "Deny"
    actions = [
      "s3:CreateBucket"
    ]
    resources = ["arn:aws:s3:::*"]
  }
}

# SCP: Prevent disabling security services
resource "aws_organizations_policy" "protect_security_services" {
  name            = "${var.name_prefix}-protect-security-services"
  description     = "Prevent disabling GuardDuty, Security Hub, or Config"
  type            = "SERVICE_CONTROL_POLICY"
  content         = data.aws_iam_policy_document.protect_security_services.json
  tags            = var.tags
}

data "aws_iam_policy_document" "protect_security_services" {
  statement {
    sid    = "DenyGuardDutyDisable"
    effect = "Deny"
    actions = [
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:DisassociateMembers"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenySecurityHubDisable"
    effect = "Deny"
    actions = [
      "securityhub:DisableSecurityHub",
      "securityhub:DeleteInvitations"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyConfigDisable"
    effect = "Deny"
    actions = [
      "config:DeleteConfigurationRecorder",
      "config:StopConfigurationRecorder",
      "config:DeleteDeliveryChannel"
    ]
    resources = ["*"]
  }
}

# Attach SCPs to OUs
resource "aws_organizations_policy_target" "deny_cloudtrail_workloads" {
  target_id  = aws_organizations_organizational_unit.workloads.id
  policy_id  = aws_organizations_policy.deny_disable_cloudtrail.id
}

resource "aws_organizations_policy_target" "require_encryption_workloads" {
  target_id  = aws_organizations_organizational_unit.workloads.id
  policy_id  = aws_organizations_policy.require_s3_encryption.id
}

resource "aws_organizations_policy_target" "protect_services_workloads" {
  target_id  = aws_organizations_organizational_unit.workloads.id
  policy_id  = aws_organizations_policy.protect_security_services.id
}

# Cross-account role for Terraform (delegated admin)
# Allows management account to assume this role in member accounts
resource "aws_iam_role" "terraform_cross_account" {
  name              = "${var.name_prefix}-terraform-cross-account"
  assume_role_policy = data.aws_iam_policy_document.terraform_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "terraform_assume_role" {
  statement {
    effect = "Allow"
    principals = {
      AWS = "arn:aws:iam::${var.management_account_id}:root"
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.terraform_external_id]
    }
  }
}

resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform_cross_account.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
