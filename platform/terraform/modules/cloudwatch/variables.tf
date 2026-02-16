variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster for metrics"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier for alarms"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold percentage for alarm"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory utilization threshold percentage for alarm"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
