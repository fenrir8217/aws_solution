project     = "demo"
environment = "test"
aws_region  = "us-east-1"

# VPC
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

# EKS
eks_node_instance_type = "t3.medium"
eks_desired_nodes      = 2
eks_min_nodes          = 2
eks_max_nodes          = 2
eks_kubernetes_version = "1.29"

# RDS
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20
rds_engine            = "postgres"
rds_engine_version    = "15.4"
rds_multi_az          = false

# MSK (Kafka)
msk_instance_type   = "kafka.t3.small"
msk_broker_count    = 2
msk_ebs_volume_size = 10

# ElastiCache (Redis)
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1
redis_engine_version  = "7.0"

# Tags
tags = {
  ManagedBy = "terraform"
  Team      = "platform"
}
