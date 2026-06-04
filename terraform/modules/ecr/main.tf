# ECR Repositories for container images
# Best practice: one repo per microservice/component. Scan on push. Lifecycle to control costs.

resource "aws_ecr_repository" "backend" {
  count                = var.create ? 1 : 0
  name                 = "ha-backend"
  image_tag_mutability = "MUTABLE"  # or IMMUTABLE for prod best practice

  image_scanning_configuration {
    scan_on_push = true  # Basic scanning (free). For enhanced + Inspector, enable in ECR settings or use enhanced scanning.
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "backend"
  }
}

# Optional: Lifecycle policy to keep only last N images (saves storage costs)
resource "aws_ecr_lifecycle_policy" "backend" {
  count      = var.create ? 1 : 0
  repository = var.create ? aws_ecr_repository.backend[0].name : null

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
