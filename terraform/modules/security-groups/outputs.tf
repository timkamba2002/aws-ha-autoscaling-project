output "alb_sg_id" {
  value = var.create ? aws_security_group.alb_sg[0].id : data.aws_security_group.alb_sg[0].id
}

output "ec2_sg_id" {
  value = var.create ? aws_security_group.ec2_sg[0].id : data.aws_security_group.ec2_sg[0].id
}


