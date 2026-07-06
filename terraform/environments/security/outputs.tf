output "cloudtrail_bucket_name" {
  description = "S3 bucket storing CloudTrail logs"
  value       = module.security_logging.cloudtrail_s3_bucket_name
}

output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = module.security_logging.cloudtrail_arn
}

output "security_hub_arn" {
  description = "ARN of Security Hub hub"
  value       = module.security_hub.hub_arn
}

output "finding_aggregator_arn" {
  description = "ARN of the Security Hub finding aggregator"
  value       = module.security_hub.finding_aggregator_arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = module.guardduty.detector_id
}

output "guardduty_detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = module.guardduty.detector_arn
}

output "security_findings_sns_topic" {
  description = "SNS topic for Security Hub findings"
  value       = module.security_hub.sns_topic_arn
}

output "guardduty_findings_sns_topic" {
  description = "SNS topic for GuardDuty findings"
  value       = module.guardduty.sns_topic_arn
}

output "identity_center_instance_arn" {
  description = "ARN of Identity Center instance"
  value       = module.iam_identity_center.identity_center_instance_arn
}

output "entra_id_setup_guide" {
  description = "Instructions for Entra ID federation"
  value       = module.iam_identity_center.entra_id_setup_instructions
}
