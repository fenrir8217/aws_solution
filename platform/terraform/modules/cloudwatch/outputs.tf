output "application_log_group_name" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "ARN of the application log group"
  value       = aws_cloudwatch_log_group.application.arn
}

output "eks_log_group_name" {
  description = "Name of the EKS log group"
  value       = aws_cloudwatch_log_group.eks.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "cpu_alarm_arn" {
  description = "ARN of the EKS CPU alarm"
  value       = aws_cloudwatch_metric_alarm.eks_cpu_high.arn
}

output "memory_alarm_arn" {
  description = "ARN of the EKS memory alarm"
  value       = aws_cloudwatch_metric_alarm.eks_memory_high.arn
}
