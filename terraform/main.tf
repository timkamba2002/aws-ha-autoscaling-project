# ==================== HA PROJECT - MAIN TERRAFORM CONFIG ====================

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
  source = "./modules/alb"
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id = module.security_groups.alb_sg_id
  vpc_id = var.environment == "development" ? module.vpc.vpc_id : "vpc-0d4035555d90998ca"
  create = var.environment == "development"
}

module "ec2" {
  source = "./modules/ec2"
  ec2_sg_id = module.security_groups.ec2_sg_id
  frontend_bucket_name = var.frontend_builds_bucket
  environment = var.environment
  frontend_s3_prefix = var.frontend_s3_prefix
}

module "autoscaling" {
  source = "./modules/autoscaling"
  private_subnet_ids = module.vpc.private_subnet_ids
  launch_template_id = module.ec2.launch_template_id
  target_group_arn = module.alb.target_group_arn
  create_asg = var.environment == "development"
}

# S3 bucket for React frontend build artifacts
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

# Private subnets internet access in development (via IGW - no NAT/EIP)
resource "aws_route" "private_igw_route_dev" {
  count = var.environment == "development" ? 1 : 0

  route_table_id         = module.vpc.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc.internet_gateway_id
}

# Monitoring
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-ha-project-alarms"
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "monitoring" {
  source = "./modules/monitoring"
  environment = var.environment
  backend_log_group_name = "/aws/ec2/ha-project-${var.environment}-backend"
  rds_instance_identifier = try(aws_db_instance.main[0].identifier, "myapp-rds")
  rds_cpu_threshold = 80
  rds_free_storage_threshold_bytes = 5 * 1024 * 1024 * 1024
  alarm_sns_topic_arn = aws_sns_topic.alarms.arn
  enable_connection_alarm = true
  rds_max_connections_threshold = 80
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECR
module "ecr" {
  source = "./modules/ecr"
  environment = var.environment
  create = var.environment == "development"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  count = var.environment == "development" ? 1 : 0
  name = "ha-project-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "backend" {
  count = var.environment == "development" ? 1 : 0
  family                   = "ha-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution[0].arn

  container_definitions = jsonencode([
    {
      name = "backend"
      image = "866934333672.dkr.ecr.us-east-1.amazonaws.com/ha-backend:sha-placeholder"
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
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
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

# IAM for ECS
resource "aws_iam_role" "ecs_execution" {
  count = var.environment == "development" ? 1 : 0
  name = "ha-project-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  count = var.environment == "development" ? 1 : 0
  role       = aws_iam_role.ecs_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_ssm_read" {
  count = var.environment == "development" ? 1 : 0
  name  = "ha-project-ecs-ssm-read"
  role  = aws_iam_role.ecs_execution[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:us-east-1:866934333672:parameter/ha-project/*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "ecs_backend" {
  count             = var.environment == "development" ? 1 : 0
  name              = "/ecs/ha-backend"
  retention_in_days = 90
}

# ECS Service
resource "aws_ecs_service" "backend" {
  count = var.environment == "development" ? 1 : 0
  name            = "ha-backend-service"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.backend[0].arn
  desired_count   = 2

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

  lifecycle {
    ignore_changes = [task_definition]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ECS Security Group
resource "aws_security_group" "ecs_backend" {
  count       = var.environment == "development" ? 1 : 0
  name        = "ha-backend-ecs-sg"
  description = "Security group for ECS backend tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [module.security_groups.alb_sg_id]
  }

  ingress {
    description     = "Allow from EC2 ASG"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [module.security_groups.ec2_sg_id]
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

# ECS Target Group
resource "aws_lb_target_group" "ecs_backend" {
  count       = var.environment == "development" ? 1 : 0
  name        = "ha-backend-ecs-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

# ALB Listener Rule - Route /api/* to ECS
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
  }
}