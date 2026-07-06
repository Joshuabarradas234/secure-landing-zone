output "detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = aws_guardduty_detector.main.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for GuardDuty findings"
  value       = aws_sns_topic.guardduty_findings.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for GuardDuty findings"
  value       = aws_sns_topic.guardduty_findings.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for GuardDuty findings"
  value       = aws_cloudwatch_log_group.guardduty.name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda role for GuardDuty processing (if needed)"
  value       = aws_iam_role.guardduty_processor.arn
}
