# IAM
data "aws_iam_policy_document" "portchain_execution_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "portchain_execution_role" {
  name               = "portchain_execution_role"
  assume_role_policy = data.aws_iam_policy_document.portchain_execution_role_assume_role_policy.json
}

data "aws_iam_policy_document" "portchain_logs_access" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "portchain_logs_access" {
  name = "portchain_logs_access"
  role = aws_iam_role.portchain_execution_role.id

  policy = data.aws_iam_policy_document.portchain_logs_access.json
}

# Security groups
resource "aws_security_group" "ecs_load_balancer" {
  name = "ecs_load_balancer"

  ingress {
    description = "world http access (secured with auth headers, with TLS upstream)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "onward traffic and healthchecks to containers"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_portchain_container.id]
  }
}

resource "aws_security_group" "ecs_node" {
  name = "ecs_node"

  egress {
    description = "outbound SSL for ECS registration"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_portchain_container" {
  name = "ecs_portchain_container"
}

resource "aws_security_group_rule" "container_ingress" {
  description              = "inbound traffic including healthcheck from load balancer"
  security_group_id        = aws_security_group.ecs_portchain_container.id
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  type                     = "ingress"
  source_security_group_id = aws_security_group.ecs_load_balancer.id
}
