variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "ecr-demo-app"
}

variable "environment" {
  description = "Deployment environment tag"
  type        = string
  default     = "demo"
}

variable "max_images" {
  description = "Number of images to retain in ECR (lifecycle policy)"
  type        = number
  default     = 10
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}
