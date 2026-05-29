output "alb_arn" {
  value = aws_lb.alb.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB. Update React TodoApp.tsx API_BASE to use http://<this-value>/api"
  value       = aws_lb.alb.dns_name
}
