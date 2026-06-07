output "backend_repository_url" {
  description = "ECR repository URL for the backend image (used by pipeline to push and by task definitions)"
  value       = var.create ? aws_ecr_repository.backend[0].repository_url : ""
}

output "backend_repository_name" {
  description = "ECR repository name"
  value       = var.create ? aws_ecr_repository.backend[0].name : ""
}
