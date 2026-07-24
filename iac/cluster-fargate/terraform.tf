terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  backend "s3" {
    bucket = "tf-state-540910306996-us-east-1-an"
    key    = "ecs-tf-simple/cluster-fargate"
    region = "us-east-1"
  }

  required_version = ">= 1.15.2"
}