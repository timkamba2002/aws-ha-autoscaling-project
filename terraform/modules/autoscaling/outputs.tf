output "asg_name" {
  value = var.create_asg ? aws_autoscaling_group.asg[0].name : "ha-project-asg"
}
