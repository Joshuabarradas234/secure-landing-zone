#############################################
# Security Hub Module
# Purpose: Central security findings aggregator
#############################################

# Enable Security Hub in the aggregator account
resource "aws_securityhub_hub" "main" {
  enable_default_standards = var.enable_default_standards

  tags = var.tags
}

# Enable CIS AWS Foundations Benchmark
resource "aws_securityhub_standards_subscription" "cis_benchmark" {
  depends_on       = [aws_securityhub_hub.main]
  standards_arn    = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

data "aws_region" "current" {}

# Enable PCI DSS standard (if needed for compliance)
resource "aws_securityhub_standards_subscription" "pci_dss" {
  count            = var.enable_pci_dss ? 1 : 0
  depends_on       = [aws_securityhub_hub.main]
  standards_arn    = "arn:aws:securityhub:${data.aws_region.current.name}::standards/pci-dss/v/3.2.1"
}

# Create finding aggregator for multi-region findings
resource "aws_securityhub_finding_aggregator" "main" {
  depends_on = [aws_securityhub_hub.main]

  account_aggregation_sources {
    account_ids = var.member_account_ids
  }

  all_regions = true
}

# EventBridge rule to catch high/critical findings and trigger alerts
resource "aws_cloudwatch_event_rule" "critical_findings" {
  name        = "${var.name_prefix}-critical-findings"
  description = "Capture critical Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      severity = {
        label = ["CRITICAL", "HIGH"]
      }
      compliance = {
        status = ["FAILED"]
      }
    }
  })
}

# Send to SNS topic for notifications
resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.critical_findings.name
  target_id = "SecurityHubFindings"
  arn       = aws_sns_topic.security_findings.arn

  input_transformer {
    input_paths = {
      finding  = "$.detail.findings[0]"
      severity = "$.detail.findings[0].Severity.Label"
    }
    input_template = "\"Security Hub finding [\"><severity>\" severity]: <finding>\""
  }
}

# SNS Topic for Security Hub alerts
resource "aws_sns_topic" "security_findings" {
  name              = "${var.name_prefix}-security-findings"
  kms_master_key_id = "alias/aws/sns"

  tags = var.tags
}

# SNS Topic Policy to allow EventBridge to publish
resource "aws_sns_topic_policy" "security_findings" {
  arn    = aws_sns_topic.security_findings.arn
  policy = data.aws_iam_policy_document.sns_eventbridge.json
}

data "aws_iam_policy_document" "sns_eventbridge" {
  statement {
    sid    = "EventBridgePublish"
    effect = "Allow"
    principals = {
      Service = "events.amazonaws.com"
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.security_findings.arn]
  }
}

# CloudWatch Dashboard for Security Hub metrics
resource "aws_cloudwatch_dashboard" "security_posture" {
  dashboard_name = "${var.name_prefix}-security-posture"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SecurityHub", "ComplianceScore", { stat = "Average" }],
            [".", "CriticalFindingsCount", { stat = "Sum" }],
            [".", "HighFindingsCount", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "Security Posture Overview"
        }
      }
    ]
  })
}

# CloudWatch Alarm: Alert if critical findings exist
resource "aws_cloudwatch_metric_alarm" "critical_findings_count" {
  alarm_name          = "${var.name_prefix}-critical-findings-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CriticalFindingsCount"
  namespace           = "AWS/SecurityHub"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alarm if critical Security Hub findings detected"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.security_findings.arn]
}
