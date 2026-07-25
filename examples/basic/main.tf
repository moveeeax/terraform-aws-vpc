terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  description = "AWS region to deploy the example VPC into."
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../.."

  name       = "example-vpc"
  cidr_block = "10.10.0.0/16"

  # Both of these are already the defaults; they are spelled out here because
  # they create resources beyond the VPC itself: the default security group is
  # adopted and emptied, and a CloudWatch log group receives flow logs.
  manage_default_security_group = true
  enable_flow_log               = true
  flow_log_retention_in_days    = 30

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "vpc_id" {
  description = "ID of the example VPC."
  value       = module.vpc.id
}

output "flow_log_cloudwatch_log_group_name" {
  description = "Log group where this VPC's flow logs land."
  value       = module.vpc.flow_log_cloudwatch_log_group_name
}
