output "hub_arn" {
  description = "ARN of the Security Hub hub"
  value       = aws_securityhub_hub.main.arn
}

output "finding_aggregator_arn" {
  description = "ARN of the finding aggregator"
  value       = aws_securityhub_finding_aggregator.main.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for security findings"
  value       = aws_sns_topic.security_findings.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for security findings"
  value       = aws_sns_topic.security_findings.name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule for critical findings"
  value       = aws_cloudwatch_event_rule.critical_findings.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.security_posture.dashboard_name
}
