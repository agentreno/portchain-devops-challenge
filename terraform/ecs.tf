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

resource "aws_cloudwatch_log_group" "portchain_logs" {
  name = "/ecs/portchain"
}

resource "aws_ecs_cluster" "portchain" {
  name = "portchain"
}

resource "aws_ecs_task_definition" "portchain" {
  family                = "portchain"
  container_definitions = file("taskdef.json")
  network_mode          = "awsvpc"
  execution_role_arn    = aws_iam_role.portchain_execution_role.arn

  # Stops the autoincrementing task version making this resource unstable
  # Without it a tf apply would replace the task definition each time
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

