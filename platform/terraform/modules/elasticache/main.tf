resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-redis-subnet"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Allow Redis access from application"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-redis-sg"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-redis-params"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${var.project}-${var.environment}-redis"
  description          = "${var.project} ${var.environment} Redis replication group"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  port                 = var.port
  engine_version       = var.engine_version
  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "mon:05:00-mon:06:00"

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-redis"
    Project     = var.project
    Environment = var.environment
  })
}
