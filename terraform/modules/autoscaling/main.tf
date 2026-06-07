resource "aws_autoscaling_group" "asg" {
  count = var.create_asg ? 1 : 0

  name             = "ha-project-asg"
  max_size         = 4
  min_size         = 2
  desired_capacity = 2

  # Private subnets from the VPC module
  vpc_zone_identifier = var.private_subnet_ids

  # Launch template from the EC2 module
  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  # Target group from the ALB module
  target_group_arns = [var.target_group_arn]

  tag {
    key                 = "Name"
    value               = "ha-project-instance"
    propagate_at_launch = true
  }
}
