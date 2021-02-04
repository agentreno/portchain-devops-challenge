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
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_portchain_targets.arn
  }
}

# TLS Ingress
resource "aws_cloudfront_distribution" "edge" {
  enabled = true

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = "portchain"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  origin {
    domain_name = aws_lb.ecs_lb.dns_name
    origin_id   = "portchain"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
