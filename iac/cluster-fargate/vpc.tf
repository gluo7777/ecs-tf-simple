data "aws_vpc" "existing" {
  default = true
}

data "aws_subnets" "us_east_1a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "availabilityZone"
    values = ["us-east-1a"]
  }
}

data "aws_subnets" "us_east_1b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "availabilityZone"
    values = ["us-east-1b"]
  }
}

locals {
  subnet_ids = concat(
    data.aws_subnets.us_east_1a.ids,
    data.aws_subnets.us_east_1b.ids
  )
}