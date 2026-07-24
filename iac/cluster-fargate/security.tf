# ─── Service security group ─────────────────────────────────

resource "aws_security_group" "service" {
  name        = "${var.prefix}-service-sg"
  description = "Allow inbound HTTP to the nginx task"
  vpc_id      = data.aws_vpc.existing.id

  tags = {
    Name = "${var.prefix}-service-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http_in" {
  description       = "Allow HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = var.container_port
  to_port           = var.container_port
  security_group_id = aws_security_group.service.id
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.service.id
  cidr_ipv4         = "0.0.0.0/0"
}
