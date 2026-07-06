#############################################
# GuardDuty Module
# Purpose: Managed threat detection
#############################################

# Enable GuardDuty detector
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = var.tags
}

# Create SNS topic for GuardDuty findings
resource "aws_sns_topic" "guardduty_findings" {
  name              = "${var.name_prefix}-guardduty-findings"
  kms_master_key_id = "alias/aws/sns"

  tags = var.tags
}

# EventBridge rule to catch GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "${var.name_prefix}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [7.0, 7.1, 7.2, 7.3, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9]  # HIGH and CRITICAL
    }
  })
}

# EventBridge target: SNS topic
resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "GuardDutyFindings"
  arn       = aws_sns_topic.guardduty_findings.arn

  input_transformer {
    input_paths = {
      finding_type = "$.detail.type"
      severity     = "$.detail.severity"
      account      = "$.detail.accountId"
    }
    input_template = "\"GuardDuty finding in account <account>: <finding_type> (Severity: <severity>)\""
  }
}

# SNS topic policy to allow EventBridge
resource "aws_sns_topic_policy" "guardduty_findings" {
  arn    = aws_sns_topic.guardduty_findings.arn
  policy = data.aws_iam_policy_document.guardduty_sns.json
}

data "aws_iam_policy_document" "guardduty_sns" {
  statement {
    sid    = "EventBridgePublish"
    effect = "Allow"
    principals = {
      Service = "events.amazonaws.com"
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.guardduty_findings.arn]
  }
}

# CloudWatch Logs for GuardDuty findings (optional)
resource "aws_cloudwatch_log_group" "guardduty" {
  name              = "/aws/guardduty/${var.name_prefix}"
  retention_in_days = var.cloudwatch_retention_days

  tags = var.tags
}

# EventBridge rule to send findings to CloudWatch Logs
resource "aws_cloudwatch_event_target" "guardduty_logs" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "GuardDutyLogs"
  arn       = aws_cloudwatch_log_group.guardduty.arn
}

# Lambda function to process GuardDuty findings (optional, for downstream automation)
resource "aws_iam_role" "guardduty_processor" {
  name = "${var.name_prefix}-guardduty-processor"

  assume_role_policy = data.aws_iam_policy_document.guardduty_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "guardduty_assume_role" {
  statement {
    effect = "Allow"
    principals = {
      Service = "lambda.amazonaws.com"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "guardduty_processor_basic" {
  role       = aws_iam_role.guardduty_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Metric Alarm: High GuardDuty findings
resource "aws_cloudwatch_metric_alarm" "guardduty_high_findings" {
  alarm_name          = "${var.name_prefix}-guardduty-high-findings"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FindingsCount"
  namespace           = "AWS/GuardDuty"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when GuardDuty detects multiple high-severity findings"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.guardduty_findings.arn]
}
