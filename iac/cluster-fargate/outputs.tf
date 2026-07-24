output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.nginx.name
}

output "region" {
  value = var.region
}
