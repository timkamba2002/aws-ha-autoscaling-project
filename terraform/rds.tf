# DB Subnet Group (creation only in development; non-dev reuse via name)
resource "aws_db_subnet_group" "main" {
  count = var.environment == "development" ? 1 : 0

  name       = "main-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name        = "main-db-subnet-group"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Security Group for RDS (MySQL - matches existing myapp-rds)
resource "aws_security_group" "rds_sg" {
  count = var.environment == "development" ? 1 : 0

  name        = "rds-security-group"
  description = "Allow MySQL from EC2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = concat(
      [module.security_groups.ec2_sg_id],
      # Allow the ECS Fargate tasks (backend moved to containers on Fargate Spot)
      # Note: aws_security_group.ecs_backend is defined in main.tf (dev only)
      var.environment == "development" ? [aws_security_group.ecs_backend[0].id] : []
    )
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "rds-security-group"
    Environment = var.environment
  }

  # Ignore description changes (in case it drifts) to avoid unnecessary SG replacement.
  # We only want to update the ingress rules in-place.
  lifecycle {
    ignore_changes = [description]
  }
}

# PostgreSQL RDS Instance (import existing if identifier matches)
# If you have an old MySQL instance, keep it and create this new one with a different identifier.
# Read DB password from SSM Parameter Store (preferred method) - uses environment for multi-env support.
# The data source is only read if no db_password var is passed (e.g. local runs); pipeline always passes the var.
data "aws_ssm_parameter" "db_password" {
  count           = var.db_password == null ? 1 : 0
  name            = "/ha-project/${var.environment}/db_password"
  with_decryption = true
}

data "aws_db_instance" "main" {
  count                  = var.environment == "development" ? 0 : 1
  db_instance_identifier = "myapp-rds"
}

resource "aws_db_instance" "main" {
  count = var.environment == "development" ? 1 : 0

  identifier        = "myapp-rds"
  engine            = "mysql"
  engine_version    = "8.0.45"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "myappdb"
  username = "admin"
  password = var.db_password != null ? var.db_password : try(data.aws_ssm_parameter.db_password[0].value, "")

  vpc_security_group_ids = [aws_security_group.rds_sg[0].id]
  db_subnet_group_name   = aws_db_subnet_group.main[0].name

  skip_final_snapshot     = true
  publicly_accessible     = false
  backup_retention_period = 7

  tags = {
    Name        = "myapp-rds"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Store connection details in SSM so EC2 user-data can reliably fetch them (now env-specific)
resource "aws_ssm_parameter" "db_host" {
  name      = "/ha-project/${var.environment}/db_host"
  type      = "String"
  value     = split(":", try(aws_db_instance.main[0].endpoint, data.aws_db_instance.main[0].endpoint))[0]
  overwrite = true # Prevents "ParameterAlreadyExists" errors

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "db_user" {
  name      = "/ha-project/${var.environment}/db_user"
  type      = "String"
  value     = "admin"
  overwrite = true # Prevents "ParameterAlreadyExists" errors on re-runs

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
