variable "project" {
  description = "Project name"
  type        = string
  default     = "demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "pre-prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

# EKS
variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
}

variable "eks_desired_nodes" {
  description = "Desired number of EKS worker nodes"
  type        = number
}

variable "eks_min_nodes" {
  description = "Minimum number of EKS worker nodes"
  type        = number
}

variable "eks_max_nodes" {
  description = "Maximum number of EKS worker nodes"
  type        = number
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

# RDS
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
}

variable "rds_engine" {
  description = "RDS database engine"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "15.4"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
}

# MSK (Kafka)
variable "msk_instance_type" {
  description = "MSK broker instance type"
  type        = string
}

variable "msk_broker_count" {
  description = "Number of MSK broker nodes"
  type        = number
}

variable "msk_ebs_volume_size" {
  description = "EBS volume size per MSK broker in GB"
  type        = number
}

# ElastiCache (Redis)
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
