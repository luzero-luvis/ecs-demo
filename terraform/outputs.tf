output "app_url" {
  description = "URL to access the application"
  value       = "http://${aws_lb.app.dns_name}"
}

output "repository_url" {
  description = "ECR repository URI — used by the push script"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "logs_command" {
  description = "Command to tail live container logs"
  value       = "aws logs tail /ecs/${var.repo_name} --follow --region ${var.aws_region}"
}
