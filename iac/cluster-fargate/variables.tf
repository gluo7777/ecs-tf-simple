variable "prefix" {
  type    = string
  default = "ecs-simple"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "container_image" {
  type    = string
  default = "nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}
