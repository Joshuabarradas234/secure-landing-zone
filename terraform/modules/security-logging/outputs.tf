output "cloudtrail_s3_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "cloudtrail_s3_bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = aws_s3_bucket.cloudtrail_logs.arn
}

output "cloudtrail_id" {
  description = "ID of the organization CloudTrail"
  value       = aws_cloudtrail.organization.id
}

output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = aws_cloudtrail.organization.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for CloudTrail events"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudTrail alerts"
  value       = aws_sns_topic.cloudtrail_alerts.arn
}
