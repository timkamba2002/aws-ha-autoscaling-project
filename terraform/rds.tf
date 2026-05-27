# Data source for DB password from SSM
data "aws_ssm_parameter" "db_password" {
  name = "/ha3tier/db/password"
}

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name = "main-db-subnet-group"
  }
}

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
    Name = "rds-security-group"
  }
}

resource "aws_db_instance" "main" {
  identifier = "myapp-rds"
  engine     = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  allocated_storage = 20

  db_name  = "myappdb"
  username = "admin"
  password = data.aws_ssm_parameter.db_password.value

  # Explicit dependency to ensure security group is created first
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  db_subnet_group_name = aws_db_subnet_group.main.name

  skip_final_snapshot = true
  publicly_accessible = false

  tags = {
    Name = "myapp-rds"
  }

  # Ensure creation order
  depends_on = [
    aws_security_group.rds_sg,
    aws_db_subnet_group.main
  ]
}