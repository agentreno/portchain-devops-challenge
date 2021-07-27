# Ingress
resource "aws_lb" "ecs_lb" {
  name               = "ecs-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.ecs_load_balancer.id]
}

resource "aws_lb_target_group" "ecs_portchain_targets" {
  name        = "ecs-portchain-targets"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  depends_on = [aws_lb.ecs_lb]
}

resource "aws_lb_listener" "portchain_forward" {
  load_balancer_arn = aws_lb.ecs_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.api.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_portchain_targets.arn
  }
}

data "aws_route53_zone" "zone" {
  name = "mindmymoney.co.uk"
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "api.mindmymoney.co.uk"
  ttl     = "360"
  type    = "CNAME"
  records = [aws_lb.ecs_lb.dns_name]
}

resource "aws_acm_certificate" "api" {
  domain_name       = aws_route53_record.record.fqdn
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.api.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.api.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.api.domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.zone.id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "validation" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}
