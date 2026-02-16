variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "enable_log_file_validation" {
  description = "Enable log file integrity validation"
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Whether the trail is created in all regions"
  type        = bool
  default     = true
}

variable "s3_log_retention_days" {
  description = "Number of days to retain S3 logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
