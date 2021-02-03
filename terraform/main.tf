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
    actions   = ["logs:*"]
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
}

resource "aws_ecs_service" "portchain" {
  name            = "portchain"
  cluster         = aws_ecs_cluster.portchain.id
  task_definition = aws_ecs_task_definition.portchain.id
  desired_count   = 1

  network_configuration {
    subnets = data.aws_subnet_ids.default.ids
  }

  depends_on = [aws_iam_role_policy.portchain_logs_access]
}

# Outputs
output "subnets" {
  value = data.aws_subnet_ids.default.ids
}
