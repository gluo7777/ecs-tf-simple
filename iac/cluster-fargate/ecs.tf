# ─── Cluster ─────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = "${var.prefix}-cluster"
}

# ─── Logs ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/${var.prefix}-nginx"
  retention_in_days = 7
}

# ─── Task definition ─────────────────────────────────────────

resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.prefix}-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nginx.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  ])
}

# ─── Service ─────────────────────────────────────────────────

resource "aws_ecs_service" "nginx" {
  name            = "${var.prefix}-nginx"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution
  ]
}
