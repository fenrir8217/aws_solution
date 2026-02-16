project     = "demo"
environment = "pre-prod"
aws_region  = "us-east-1"

# VPC
vpc_cidr             = "10.2.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs = ["10.2.11.0/24", "10.2.12.0/24", "10.2.13.0/24"]

# EKS
eks_node_instance_type = "t3.large"
eks_desired_nodes      = 3
eks_min_nodes          = 3
eks_max_nodes          = 3
eks_kubernetes_version = "1.29"

# RDS
rds_instance_class    = "db.t3.medium"
rds_allocated_storage = 50
rds_engine            = "postgres"
rds_engine_version    = "15.4"
rds_multi_az          = true

# MSK (Kafka)
msk_instance_type   = "kafka.m5.large"
msk_broker_count    = 3
msk_ebs_volume_size = 50

# ElastiCache (Redis)
redis_node_type       = "cache.t3.small"
redis_num_cache_nodes = 2
redis_engine_version  = "7.0"

# Tags
tags = {
  ManagedBy = "terraform"
  Team      = "platform"
}
