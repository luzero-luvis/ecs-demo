data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── Security Group: ALB ────────────────────────────────────────────────────────
# Accepts port 80 from the internet
resource "aws_security_group" "alb" {
  name        = "${var.repo_name}-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

# ── Security Group: ECS Tasks ──────────────────────────────────────────────────
# Only accepts traffic from the ALB, not from the internet directly
resource "aws_security_group" "app" {
  name        = "${var.repo_name}-app-sg"
  description = "Allow inbound from ALB only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

# ── ALB ────────────────────────────────────────────────────────────────────────
resource "aws_lb" "app" {
  name               = "${var.repo_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.repo_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── IAM Task Execution Role ────────────────────────────────────────────────────
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole-${var.repo_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── CloudWatch Log Group ───────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.repo_name}"
  retention_in_days = 7

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

# ── ECS Cluster ────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "app" {
  name = "${var.repo_name}-cluster"

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

# ── Task Definition ────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.repo_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = var.repo_name
    image = "${aws_ecr_repository.app.repository_url}:latest"

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "ENVIRONMENT", value = var.environment },
      { name = "IMAGE_URI",   value = "${aws_ecr_repository.app.repository_url}:latest" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    essential = true
  }])

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}

# ── ECS Service ────────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${var.repo_name}-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.repo_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.app]

  tags = { Project = "ecr-demo", ManagedBy = "terraform" }
}
