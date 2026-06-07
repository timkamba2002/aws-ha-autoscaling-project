output "backend_log_group_name" {
  value = aws_cloudwatch_log_group.backend.name
}

output "rds_cpu_alarm_name" {
  value = aws_cloudwatch_metric_alarm.rds_cpu_high.alarm_name
}

output "rds_free_storage_alarm_name" {
  value = aws_cloudwatch_metric_alarm.rds_free_storage_low.alarm_name
}
