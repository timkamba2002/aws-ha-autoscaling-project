output "alb_dns_name" {
  description = "DNS name of the ALB - update React TodoApp.tsx API_BASE to http://<this-value>/api (run 'terraform output alb_dns_name' after apply)"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint (host:port) - use in backend EC2 user-data or SSM for DB_HOST"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "frontend_s3_bucket" {
  value = aws_s3_bucket.frontend_builds.id
}
