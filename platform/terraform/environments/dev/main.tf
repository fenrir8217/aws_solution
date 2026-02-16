terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "demo-terraform-state"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "demo-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
  tags        = var.tags
}

# -----------------------------------------------------------------------------
# EKS
# -----------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  node_instance_type = var.eks_node_instance_type
  desired_nodes      = var.eks_desired_nodes
  min_nodes          = var.eks_min_nodes
  max_nodes          = var.eks_max_nodes
  kubernetes_version = var.eks_kubernetes_version
  tags               = var.tags
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  engine            = var.rds_engine
  engine_version    = var.rds_engine_version
  multi_az          = var.rds_multi_az
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# MSK (Kafka)
# -----------------------------------------------------------------------------
module "msk" {
  source = "../../modules/msk"

  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  instance_type   = var.msk_instance_type
  broker_count    = var.msk_broker_count
  ebs_volume_size = var.msk_ebs_volume_size
  tags            = var.tags
}

# -----------------------------------------------------------------------------
# ElastiCache (Redis)
# -----------------------------------------------------------------------------
module "elasticache" {
  source = "../../modules/elasticache"

  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  node_type       = var.redis_node_type
  num_cache_nodes = var.redis_num_cache_nodes
  engine_version  = var.redis_engine_version
  tags            = var.tags
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
  tags        = var.tags
}

# -----------------------------------------------------------------------------
# API Gateway
# -----------------------------------------------------------------------------
module "api_gateway" {
  source = "../../modules/api-gateway"

  project     = var.project
  environment = var.environment
  tags        = var.tags
}

# -----------------------------------------------------------------------------
# CloudWatch
# -----------------------------------------------------------------------------
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project     = var.project
  environment = var.environment
  tags        = var.tags
}

# -----------------------------------------------------------------------------
# CloudTrail
# -----------------------------------------------------------------------------
module "cloudtrail" {
  source = "../../modules/cloudtrail"

  project     = var.project
  environment = var.environment
  tags        = var.tags
}
