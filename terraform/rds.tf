# DB Subnet Group (import if "main-db-subnet-group" already exists)
resource "aws_db_subnet_group" "main" {
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
  name        = "rds-security-group"
  description = "Allow MySQL from EC2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
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
    Name        = "rds-security-group"
    Environment = var.environment
  }
}

# PostgreSQL RDS Instance (import existing if identifier matches)
# If you have an old MySQL instance, keep it and create this new one with a different identifier.
# Read DB password from SSM Parameter Store (preferred method)
data "aws_ssm_parameter" "db_password" {
  name            = "/ha-project/development/db_password"
  with_decryption = true
}

resource "aws_db_instance" "main" {
  identifier             = "myapp-rds"
  engine                 = "mysql"
  engine_version         = "8.0.45"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20

  db_name                = "myappdb"
  username               = "admin"
  password               = coalesce(var.db_password, data.aws_ssm_parameter.db_password.value)

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  skip_final_snapshot    = true
  publicly_accessible    = false
  backup_retention_period = 7

  tags = {
    Name        = "myapp-rds"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Store connection details in SSM so EC2 user-data can reliably fetch them
resource "aws_ssm_parameter" "db_host" {
  name      = "/ha-project/development/db_host"
  type      = "String"
  value     = aws_db_instance.main.endpoint
  overwrite = true   # Prevents "ParameterAlreadyExists" errors

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ssm_parameter" "db_user" {
  name      = "/ha-project/development/db_user"
  type      = "String"
  value     = "admin"
  overwrite = true   # Prevents "ParameterAlreadyExists" errors on re-runs

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
