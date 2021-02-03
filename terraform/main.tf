# Data sources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

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
    actions = ["logs:*"]
    # resources = [aws_cloudwatch_log_group.portchain_logs.arn]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "portchain_logs_access" {
  name = "portchain_logs_access"
  role = aws_iam_role.portchain_execution_role.id

  policy = data.aws_iam_policy_document.portchain_logs_access.json
}

# Logging
resource "aws_cloudwatch_log_group" "portchain_logs" {
  name = "/ecs/portchain"
}

# ECS
data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

data "aws_iam_instance_profile" "ecs_instance_role" {
  name = "ecsInstanceRole"
}

resource "aws_launch_template" "ecs_node" {
  name_prefix   = "ecs"
  image_id      = data.aws_ami.ecs_ami.image_id
  instance_type = "t2.micro"

  iam_instance_profile {
    name = data.aws_iam_instance_profile.ecs_instance_role.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_node.id]
  }

  user_data = filebase64("ecs_bootstrap.sh")
}

resource "aws_autoscaling_group" "ecs_capacity" {
  name                = "ecs-capacity-pool"
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  # No scale-in/out behaviour for now
  desired_capacity = 1
  max_size         = 1
  min_size         = 1

  launch_template {
    id      = aws_launch_template.ecs_node.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_capacity.arn

    managed_scaling {
      # Start with no ECS scaling of the ASG, single-instance
      status = "DISABLED"
    }
  }
}

resource "aws_ecs_cluster" "portchain" {
  name = "portchain"
}

resource "aws_ecs_task_definition" "portchain" {
  family                = "portchain"
  container_definitions = file("taskdef.json")
  network_mode          = "awsvpc"
  execution_role_arn    = aws_iam_role.portchain_execution_role.arn

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_ecs_service" "portchain" {
  name            = "portchain"
  cluster         = aws_ecs_cluster.portchain.id
  task_definition = aws_ecs_task_definition.portchain.id
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnet_ids.default.ids
    security_groups = [aws_security_group.ecs_portchain_container.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_portchain_targets.arn
    container_name   = "portchain"
    container_port   = 3000
  }

  # Stops the autoincrementing task version making this resource unstable
  # Without it a tf apply would replace the cluster each time
  lifecycle {
    ignore_changes = [task_definition]
  }
  depends_on = [aws_iam_role_policy.portchain_logs_access]
}

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

# Outputs
output "load_balancer_dns" {
  value = aws_lb.ecs_lb.dns_name
}
