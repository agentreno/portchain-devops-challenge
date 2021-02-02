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
    resources = [aws_cloudwatch_log_group.portchain_logs.arn]
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
