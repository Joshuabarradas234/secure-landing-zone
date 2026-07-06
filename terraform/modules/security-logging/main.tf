#############################################
# Security Logging Module
# Purpose: Central CloudTrail + immutable S3
#############################################

# S3 bucket for CloudTrail logs (encryption + versioning)
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.name_prefix}-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

data "aws_caller_identity" "current" {}

# Block public access
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning (required for MFA delete)
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"  # Set to Enabled if MFA delete enforcement needed
  }
}

# Enable encryption at rest (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy: Allow CloudTrail service to write logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]
}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals = {
      Service = "cloudtrail.amazonaws.com"
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals = {
      Service = "cloudtrail.amazonaws.com"
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# Lifecycle policy: Move old logs to Glacier for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "move-to-glacier"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
  }
}

# CloudTrail for organization-wide logging
resource "aws_cloudtrail" "organization" {
  name                          = "${var.name_prefix}-org-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.cloudtrail_logs]
  is_organization_trail         = true

  # CloudTrail requires the trail to be created before it can be enabled
  # Setting this to true enables data events (more verbose, more cost)
  # Set to false initially for cost control
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags
}

# CloudWatch Log Group for CloudTrail events (optional, adds cost)
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${var.name_prefix}"
  retention_in_days = var.cloudwatch_retention_days

  tags = var.tags
}

# IAM role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${var.name_prefix}-cloudtrail-cloudwatch"

  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    effect = "Allow"
    principals = {
      Service = "cloudtrail.amazonaws.com"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name   = "${var.name_prefix}-cloudtrail-cloudwatch-policy"
  role   = aws_iam_role.cloudtrail_cloudwatch.id
  policy = data.aws_iam_policy_document.cloudtrail_cloudwatch.json
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:*"]
  }
}

# SNS Topic for CloudTrail alerts (optional integration)
resource "aws_sns_topic" "cloudtrail_alerts" {
  name              = "${var.name_prefix}-cloudtrail-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = var.tags
}

resource "aws_sns_topic_policy" "cloudtrail_alerts" {
  arn    = aws_sns_topic.cloudtrail_alerts.arn
  policy = data.aws_iam_policy_document.cloudtrail_sns.json
}

data "aws_iam_policy_document" "cloudtrail_sns" {
  statement {
    sid    = "CloudTrailPublish"
    effect = "Allow"
    principals = {
      Service = "cloudtrail.amazonaws.com"
    }
    actions = ["SNS:Publish"]
    resources = [aws_sns_topic.cloudtrail_alerts.arn]
  }
}
