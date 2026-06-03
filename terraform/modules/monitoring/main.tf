# CloudWatch Log Group for backend application logs
resource "aws_cloudwatch_log_group" "backend" {
  name              = var.backend_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "ha-project-backend-logs"
  })
}

# Optional: Log stream (usually created automatically by the app)
resource "aws_cloudwatch_log_stream" "backend_app" {
  name           = "${var.environment}-application"
  log_group_name = aws_cloudwatch_log_group.backend.name
}

# ==================== RDS CloudWatch Alarms ====================

# High CPU Utilization on RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.environment}-rds-cpu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_description   = "RDS CPU utilization is above ${var.rds_cpu_threshold}%"
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# Low Free Storage Space on RDS
resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  alarm_name          = "${var.environment}-rds-free-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_free_storage_threshold_bytes # e.g. 5GB = 5368709120
  alarm_description   = "RDS free storage space is below 5GB"
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}

# Database Connections (optional but useful)
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count = var.enable_connection_alarm ? 1 : 0

  alarm_name          = "${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_max_connections_threshold
  alarm_description   = "RDS connection count is high"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  alarm_actions = var.alarm_sns_topic_arn != null ? [var.alarm_sns_topic_arn] : []

  tags = var.tags
}
