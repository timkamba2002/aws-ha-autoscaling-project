output "alb_dns_name" {
  description = "DNS name of the ALB - update React TodoApp.tsx API_BASE to http://<this-value>/api (run 'terraform output alb_dns_name' after apply)"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port) - use in backend EC2 user-data or SSM for DB_HOST"
  value       = try(aws_db_instance.main[0].endpoint, "N/A (managed in development state)")
  sensitive   = true
}

output "frontend_s3_bucket" {
  value = try(aws_s3_bucket.frontend_builds[0].id, var.frontend_builds_bucket)
}

output "backend_cloudwatch_log_group" {
  value = module.monitoring.backend_log_group_name
}

output "rds_identifier" {
  value = try(aws_db_instance.main[0].identifier, "myapp-rds")
}
