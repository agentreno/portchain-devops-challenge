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
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "portchain_logs_access" {
  name = "portchain_logs_access"
  role = aws_iam_role.portchain_execution_role.id

  policy = data.aws_iam_policy_document.portchain_logs_access.json
}

output "subnets" {
  value = data.aws_subnet_ids.default.ids
}
