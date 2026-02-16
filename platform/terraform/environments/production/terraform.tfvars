project     = "demo"
environment = "production"
aws_region  = "us-east-1"

# VPC
vpc_cidr             = "10.3.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.3.1.0/24", "10.3.2.0/24", "10.3.3.0/24"]
private_subnet_cidrs = ["10.3.11.0/24", "10.3.12.0/24", "10.3.13.0/24"]

# EKS (autoscaling: 3 min, 6 max)
eks_node_instance_type = "t3.xlarge"
eks_desired_nodes      = 3
eks_min_nodes          = 3
eks_max_nodes          = 6
eks_kubernetes_version = "1.29"

# RDS
rds_instance_class    = "db.r5.large"
rds_allocated_storage = 100
rds_engine            = "postgres"
rds_engine_version    = "15.4"
rds_multi_az          = true

# MSK (Kafka)
msk_instance_type   = "kafka.m5.large"
msk_broker_count    = 3
msk_ebs_volume_size = 100

# ElastiCache (Redis)
redis_node_type       = "cache.r5.large"
redis_num_cache_nodes = 3
redis_engine_version  = "7.0"

# Tags
tags = {
  ManagedBy = "terraform"
  Team      = "platform"
}
