resource "aws_security_group" "msk" {
  name        = "${var.project}-${var.environment}-msk-sg"
  description = "Security group for MSK Kafka cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Kafka plaintext"
  }

  ingress {
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Kafka TLS"
  }

  ingress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "ZooKeeper"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-msk-sg"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "msk" {
  name              = "/msk/${var.project}-${var.environment}"
  retention_in_days = 14

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_msk_configuration" "main" {
  name              = "${var.project}-${var.environment}-msk-config"
  kafka_versions    = [var.kafka_version]

  server_properties = <<PROPERTIES
auto.create.topics.enable=false
default.replication.factor=3
min.insync.replicas=2
num.partitions=6
log.retention.hours=168
PROPERTIES
}

resource "aws_msk_cluster" "main" {
  cluster_name           = "${var.project}-${var.environment}-msk"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_ebs_volume_size
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-msk"
    Project     = var.project
    Environment = var.environment
  })
}
