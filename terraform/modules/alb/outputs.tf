output "alb_arn" {
  value = var.create ? aws_lb.alb[0].arn : data.aws_lb.alb[0].arn
}

output "target_group_arn" {
  value = var.create ? aws_lb_target_group.tg[0].arn : data.aws_lb_target_group.tg[0].arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Update React TodoApp.tsx API_BASE to use http://<this-value>/api"
  value       = var.create ? aws_lb.alb[0].dns_name : data.aws_lb.alb[0].dns_name
}

output "listener_arn" {
  description = "ARN of the HTTP listener (for adding path-based rules e.g. /api/* -> ECS)"
  value       = var.create ? aws_lb_listener.listener[0].arn : data.aws_lb_listener.existing[0].arn
}
