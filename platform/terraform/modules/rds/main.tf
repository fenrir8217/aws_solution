resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-db-subnet"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Allow MySQL access from application"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-rds-sg"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-mysql-params"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-mysql"

  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az            = true
  publicly_accessible = false
  storage_encrypted   = true
  storage_type        = "gp3"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project}-${var.environment}-mysql-final"

  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-mysql"
    Project     = var.project
    Environment = var.environment
  })
}
