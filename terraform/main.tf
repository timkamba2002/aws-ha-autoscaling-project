module "vpc" {
  source = "./modules/vpc"
  create = var.environment == "development"
  vpc_id = var.environment == "development" ? "" : "vpc-0d4035555d90998ca"
}

module "security_groups" {
  source = "./modules/security-groups"
  vpc_id = var.environment == "development" ? module.vpc.vpc_id : "vpc-0d4035555d90998ca"
  create = var.environment == "development"
}

module "alb" {
  source            = "./modules/alb"
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  vpc_id            = var.environment == "development" ? module.vpc.vpc_id : "vpc-0d4035555d90998ca"
  create            = var.environment == "development"
}

module "ec2" {
  source               = "./modules/ec2"
  ec2_sg_id            = module.security_groups.ec2_sg_id
  frontend_bucket_name = var.frontend_builds_bucket
  environment          = var.environment
  frontend_s3_prefix   = var.frontend_s3_prefix
}

module "autoscaling" {
  source             = "./modules/autoscaling"
  private_subnet_ids = module.vpc.private_subnet_ids
  launch_template_id = module.ec2.launch_template_id
  target_group_arn   = module.alb.target_group_arn
  create_asg         = var.environment == "development"
}

# S3 bucket for React frontend build artifacts (uploaded by GitHub Actions, downloaded by EC2 on boot)
# Only created/managed in development state; staging/prod reuse the existing bucket (different prefix in user-data)
resource "aws_s3_bucket" "frontend_builds" {
  count = var.environment == "development" ? 1 : 0

  bucket = var.frontend_builds_bucket

  tags = {
    Name        = "HA Project Frontend Builds"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_builds" {
  count = var.environment == "development" ? 1 : 0

  bucket = aws_s3_bucket.frontend_builds[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend_builds" {
  count = var.environment == "development" ? 1 : 0

  bucket = aws_s3_bucket.frontend_builds[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# ==================== MONITORING (CloudWatch Logs + Alarms) ====================
# Simple SNS topic for alarm notifications (email subscription can be added manually in console or via additional resource)
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-ha-project-alarms"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "monitoring" {
  source = "./modules/monitoring"

  environment                      = var.environment
  backend_log_group_name           = "/aws/ec2/ha-project-${var.environment}-backend"
  rds_instance_identifier          = try(aws_db_instance.main[0].identifier, "myapp-rds")
  rds_cpu_threshold                = 80
  rds_free_storage_threshold_bytes = 5 * 1024 * 1024 * 1024 # 5 GB
  alarm_sns_topic_arn              = aws_sns_topic.alarms.arn
  enable_connection_alarm          = true
  rds_max_connections_threshold    = 80
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECR for container images (shared across envs via tags/digests; created in dev state for ownership)
module "ecr" {
  source      = "./modules/ecr"
  environment = var.environment
  create      = var.environment == "development"
}

# Basic ECS for container orchestration (Fargate recommended for new workloads)
# Cluster created only in dev state; other envs can reuse or extend.
resource "aws_ecs_cluster" "main" {
  count = var.environment == "development" ? 1 : 0
  name  = "ha-project-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"  # Enables CloudWatch Container Insights for metrics/logs
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Task Definition for backend (image will be updated in pipeline with ECR URI + digest)
# DB creds injected securely at runtime via SSM Parameter Store (SecureString) using execution role.
# This enables the Fargate tasks to connect to the shared RDS without embedding secrets.
resource "aws_ecs_task_definition" "backend" {
  count                    = var.environment == "development" ? 1 : 0
  family                   = "ha-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution[0].arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "866934333672.dkr.ecr.us-east-1.amazonaws.com/ha-backend:sha-placeholder"  # Overwritten in pipeline with exact digest
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "PORT", value = "3000" },
        { name = "NODE_ENV", value = "production" },
        { name = "DB_PORT", value = "3306" }
      ]
      secrets = [
        { name = "DB_HOST", valueFrom = "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/${var.environment}/db_host" },
        { name = "DB_USER", valueFrom = "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/${var.environment}/db_user" },
        { name = "DB_PASSWORD", valueFrom = "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/${var.environment}/db_password" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/ha-backend"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM role for ECS task execution (pull image, logs, secrets)
resource "aws_iam_role" "ecs_execution" {
  count = var.environment == "development" ? 1 : 0
  name  = "ha-project-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  count      = var.environment == "development" ? 1 : 0
  role       = aws_iam_role.ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional least-privilege policy: allow ECS execution role to fetch DB creds from SSM Parameter Store (SecureString)
# This is required for the secrets[] in task definition to be injected into the container at launch.
resource "aws_iam_role_policy" "ecs_ssm_read" {
  count = var.environment == "development" ? 1 : 0
  name  = "ha-project-ecs-ssm-read"
  role  = aws_iam_role.ecs_execution[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = [
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/development/db_host",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/development/db_user",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/development/db_password",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/staging/db_host",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/staging/db_user",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/staging/db_password",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/production/db_host",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/production/db_user",
        "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/production/db_password"
      ]
    }]
  })
}

# CloudWatch Log Group for ECS tasks (best practice for centralized logging)
resource "aws_cloudwatch_log_group" "ecs_backend" {
  count             = var.environment == "development" ? 1 : 0
  name              = "/ecs/ha-backend"
  retention_in_days = 30
}

# ECS Service for the backend using Fargate Spot (cost-optimized, AWS-managed, no EC2 to patch/scale)
# - capacity_provider_strategy with FARGATE_SPOT: AWS will run your tasks on spare capacity at ~70% discount.
# - You requested Fargate Spot because you don't want to manage instances.
# - Spot tasks can be interrupted (usually with 2min warning); for critical prod consider weight mix or base FARGATE.
# - Service is wired to ALB via dedicated ip target group + path rule (/api/*) so the React frontend (served by EC2 nginx)
#   calls the containerized backend without changing the ALB DNS / REACT_APP_API_BASE.
resource "aws_ecs_service" "backend" {
  count           = var.environment == "development" ? 1 : 0
  name            = "ha-backend-service"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.backend[0].arn
  desired_count   = 2

  # Fargate Spot (no launch_type when using capacity_provider_strategy)
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }

  network_configuration {
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.ecs_backend[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_backend[0].arn
    container_name   = "backend"
    container_port   = 3000
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy.ecs_ssm_read
  ]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Ignore task_definition changes because the GitHub Actions pipeline
  # registers new revisions with updated container images (via ECR digest promotion).
  # Terraform should not fight the CI/CD updates to the service.
  lifecycle {
    ignore_changes = [task_definition]
  }
}

# Security group for ECS tasks (allow outbound to RDS, etc.)
resource "aws_security_group" "ecs_backend" {
  count       = var.environment == "development" ? 1 : 0
  name        = "ha-backend-ecs-sg"
  description = "Security group for ECS backend tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow HTTP from ALB to backend API"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [module.security_groups.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ha-backend-ecs-sg"
  }
}

# Example target group (for future ALB integration)
resource "aws_lb_target_group" "ecs_backend" {
  count       = var.environment == "development" ? 1 : 0
  name        = "ha-backend-ecs-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"   # Required for Fargate

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# Path-based listener rule: send /api/* (and /api ) to the ECS Fargate tasks (higher priority than default).
# This lets you run the new serverless backend side-by-side with the legacy EC2/ASG/nginx setup.
# Frontend (React static served by nginx on EC2) keeps calling the same ALB DNS /api/... unchanged.
# Root path (and everything else) continues to hit the EC2 target group for the static site + nginx.
resource "aws_lb_listener_rule" "api_to_ecs" {
  count        = var.environment == "development" ? 1 : 0
  listener_arn = module.alb.listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_backend[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/api"]
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Route API traffic to Fargate Spot ECS service"
  }
}

# ==================== ECS CloudWatch Alarms (Container Insights + service level) ====================
# These complement the existing RDS + EC2 alarms in the monitoring module.
# Container Insights (enabled on cluster) provides task/service level CPU/Mem/Network + also custom if you publish.
resource "aws_cloudwatch_metric_alarm" "ecs_service_high_cpu" {
  count = var.environment == "development" ? 1 : 0

  alarm_name          = "${var.environment}-ecs-backend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS backend service CPU > 80% (Fargate Spot tasks)"

  dimensions = {
    ServiceName = "ha-backend-service"
    ClusterName = "ha-project-cluster"
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_service_high_memory" {
  count = var.environment == "development" ? 1 : 0

  alarm_name          = "${var.environment}-ecs-backend-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS backend service Memory > 80% (Fargate Spot tasks)"

  dimensions = {
    ServiceName = "ha-backend-service"
    ClusterName = "ha-project-cluster"
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Optional: alarm if desired tasks drop (e.g. due to Spot interruptions or failed deploys)
resource "aws_cloudwatch_metric_alarm" "ecs_running_tasks_low" {
  count = var.environment == "development" ? 1 : 0

  alarm_name          = "${var.environment}-ecs-backend-running-tasks-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Fewer than 1 running backend task on Fargate Spot (possible interruption or crash)"

  dimensions = {
    ServiceName = "ha-backend-service"
    ClusterName = "ha-project-cluster"
  }

  alarm_actions = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Starter CloudWatch Dashboard (IaC so it's reproducible + part of your portfolio story).
# Shows the golden signals for the backend + infra health. You can extend in console or code.
resource "aws_cloudwatch_dashboard" "ha_project" {
  count          = var.environment == "development" ? 1 : 0
  dashboard_name = "${var.environment}-ha-project-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "ha-backend-service", "ClusterName", "ha-project-cluster"],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "ha-project-alb"],
            [".", "RequestCount", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "ECS Fargate + ALB Latency/Throughput"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "myapp-rds"],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "RDS MySQL Health"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          query   = "SOURCE '/ecs/ha-backend' | fields @timestamp, @message | filter @message like /error|Error|Failed/ | sort @timestamp desc | limit 20"
          region  = "us-east-1"
          title   = "Recent Backend Errors (Logs Insights)"
        }
      }
    ]
  })
}
