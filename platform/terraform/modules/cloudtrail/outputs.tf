output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.main.arn
}

output "trail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.main.name
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}
