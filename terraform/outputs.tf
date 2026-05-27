output "frontend_builds_bucket" {
  description = "S3 bucket for React frontend artifacts. GitHub Actions uploads here."
  value       = aws_s3_bucket.frontend_builds.bucket
}

output "launch_template_id" {
  value = module.ec2.launch_template_id
}
