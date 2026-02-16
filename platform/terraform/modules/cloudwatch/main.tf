# --- Log Groups ---

resource "aws_cloudwatch_log_group" "application" {
  name              = "/${var.project}/${var.environment}/application"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-app-logs"
    Project     = var.project
    Environment = var.environment
  })
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-eks-logs"
    Project     = var.project
    Environment = var.environment
  })
}

# --- CPU Alarm ---

resource "aws_cloudwatch_metric_alarm" "eks_cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-eks-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "EKS cluster CPU utilization exceeds ${var.cpu_alarm_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

# --- Memory Alarm ---

resource "aws_cloudwatch_metric_alarm" "eks_memory_high" {
  alarm_name          = "${var.project}-${var.environment}-eks-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  alarm_description   = "EKS cluster memory utilization exceeds ${var.memory_alarm_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

# --- RDS CPU Alarm ---

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "RDS CPU utilization exceeds ${var.cpu_alarm_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
  })
}

# --- Dashboard ---

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS CPU Utilization"
          metrics = [["ContainerInsights", "node_cpu_utilization", "ClusterName", var.eks_cluster_name]]
          period  = 300
          stat    = "Average"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Memory Utilization"
          metrics = [["ContainerInsights", "node_memory_utilization", "ClusterName", var.eks_cluster_name]]
          period  = 300
          stat    = "Average"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "EKS Pod Count"
          metrics = [["ContainerInsights", "pod_number_of_running", "ClusterName", var.eks_cluster_name]]
          period  = 300
          stat    = "Average"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "EKS Network (Bytes/sec)"
          metrics = [
            ["ContainerInsights", "node_network_total_bytes", "ClusterName", var.eks_cluster_name]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          view   = "timeSeries"
        }
      }
    ]
  })
}
