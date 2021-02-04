# Outputs
output "tls_endpoint" {
  value = "https://${aws_cloudfront_distribution.edge.domain_name}"
}

output "load_balancer_dns" {
  value = aws_lb.ecs_lb.dns_name
}
