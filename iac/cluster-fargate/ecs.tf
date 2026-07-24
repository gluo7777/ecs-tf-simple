# ─── Cluster ─────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = "${var.prefix}-cluster"
}

# ─── Logs ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/${var.prefix}-nginx"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "threat_detector" {
  name              = "/ecs/${var.prefix}-threat-detector"
  retention_in_days = 7
}

# ─── Task definition ─────────────────────────────────────────
#
# "threat-detector" is a POC stand-in for a runtime security sensor
# (e.g. Wiz Sensor). It tails nginx's access log over a shared volume
# and greps for a few suspicious request patterns. Real syscall/eBPF-based
# sensors need privileged/hostPID access, which Fargate does not allow —
# this sidecar deliberately avoids that so it can actually run here.

resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.prefix}-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  volume {
    name = "nginx-logs"
  }

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = var.container_image
      essential = true

      # The official nginx image symlinks access.log to /dev/stdout. Remove
      # that symlink so nginx writes a real file the sidecar can tail.
      entryPoint = ["/bin/sh", "-c"]
      command = [
        "rm -f /var/log/nginx/access.log /var/log/nginx/error.log && exec nginx -g 'daemon off;'"
      ]

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "nginx-logs"
          containerPath = "/var/log/nginx"
          readOnly      = false
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
    },
    {
      name      = "threat-detector"
      image     = "alpine:3.20"
      essential = false

      dependsOn = [
        {
          containerName = "nginx"
          condition     = "START"
        }
      ]

      entryPoint = ["/bin/sh", "-c"]
      command = [
        <<-EOT
        until [ -f /var/log/nginx/access.log ]; do sleep 1; done
        tail -f /var/log/nginx/access.log | grep -iE --line-buffered '(\.\./|union select|<script|/etc/passwd|wp-login|cmd\.exe)' | \
        while read -r line; do echo "[ALERT] suspicious request: $line"; done
        EOT
      ]

      mountPoints = [
        {
          sourceVolume  = "nginx-logs"
          containerPath = "/var/log/nginx"
          readOnly      = true
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.threat_detector.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "threat-detector"
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

  enable_execute_command = true

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution
  ]
}
