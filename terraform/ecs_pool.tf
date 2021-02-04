# ECS Node Pool
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
