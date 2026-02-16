# VPC
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# EKS
output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_certificate_authority" {
  description = "Certificate authority data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

# RDS
output "rds_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Port of the RDS instance"
  value       = module.rds.port
}

# MSK
output "msk_bootstrap_brokers" {
  description = "Bootstrap brokers for the MSK cluster"
  value       = module.msk.bootstrap_brokers
}

output "msk_zookeeper_connect" {
  description = "Zookeeper connection string for the MSK cluster"
  value       = module.msk.zookeeper_connect
}

# ElastiCache
output "redis_endpoint" {
  description = "Endpoint of the Redis cluster"
  value       = module.elasticache.endpoint
}

output "redis_port" {
  description = "Port of the Redis cluster"
  value       = module.elasticache.port
}

# ECR
output "ecr_repository_urls" {
  description = "URLs of the ECR repositories"
  value       = module.ecr.repository_urls
}

# API Gateway
output "api_gateway_endpoint" {
  description = "Endpoint of the API Gateway"
  value       = module.api_gateway.endpoint
}
