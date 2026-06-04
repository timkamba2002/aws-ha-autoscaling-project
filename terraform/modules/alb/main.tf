resource "aws_lb" "alb" {
  count = var.create ? 1 : 0

  name               = "ha-project-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "ha-project-alb"
  }
}

resource "aws_lb_target_group" "tg" {
  count = var.create ? 1 : 0

  name     = "ha-project-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "listener" {
  count = var.create ? 1 : 0

  load_balancer_arn = aws_lb.alb[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
  }
}

# Data sources for reuse in non-dev envs
data "aws_lb" "alb" {
  count = var.create ? 0 : 1
  name  = "ha-project-alb"
  # Note: vpc_id is NOT a valid input for data "aws_lb" (it is an output attribute).
  # We lookup by name (which is unique per AWS account). Since only the live VPC remains,
  # this will correctly find the one created by dev.
}

data "aws_lb_target_group" "tg" {
  count = var.create ? 0 : 1
  name  = "ha-project-tg"
  # vpc_id not valid here either; name lookup is sufficient.
}
