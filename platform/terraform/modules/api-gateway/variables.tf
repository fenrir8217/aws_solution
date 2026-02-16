variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for VPC link"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the NLB"
  type        = list(string)
}

variable "nlb_arn" {
  description = "ARN of the Network Load Balancer for VPC link"
  type        = string
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
