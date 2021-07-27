# Outputs
output "load_balancer_dns" {
  value = aws_lb.ecs_lb.dns_name
}
