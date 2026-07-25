# Run with `terraform test`. Requires Terraform >= 1.7 (or OpenTofu >= 1.7) for
# `mock_provider`; the module itself still supports >= 1.5, so this test-only
# requirement is deliberately not encoded in versions.tf.

# The AWS provider validates ARN-shaped arguments during plan, so the mock has
# to hand back ARN-shaped values instead of its usual random strings. The
# account number below is the placeholder AWS uses in its own documentation.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:111122223333:log-group:/aws/vpc-flow-log/unit-test-vpc"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/unit-test-vpc-flow-log"
    }
  }
}

variables {
  name = "unit-test-vpc"
}

run "vpc_defaults" {
  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "The default VPC CIDR block changed unexpectedly."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "DNS support and hostnames should both be enabled by default."
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "unit-test-vpc"
    error_message = "The Name tag should be derived from var.name."
  }
}

run "default_security_group_is_stripped_by_default" {
  assert {
    condition     = length(aws_default_security_group.this) == 1
    error_message = "The default security group must be adopted by default so its rules are revoked."
  }

  # No ingress/egress blocks means the AWS provider revokes every rule on the
  # VPC's default security group, which is the CIS-hardened state.
  assert {
    condition     = length(aws_default_security_group.this[0].ingress) == 0
    error_message = "The default security group must have no ingress rules."
  }

  assert {
    condition     = length(aws_default_security_group.this[0].egress) == 0
    error_message = "The default security group must have no egress rules (no 0.0.0.0/0 egress)."
  }
}

run "default_security_group_can_be_left_alone" {
  variables {
    manage_default_security_group = false
  }

  assert {
    condition     = length(aws_default_security_group.this) == 0
    error_message = "manage_default_security_group = false must not adopt the default security group."
  }
}

run "flow_logs_enabled_by_default" {
  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "VPC flow logs must be enabled by default."
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "ALL"
    error_message = "Flow logs should capture ALL traffic by default, not just rejects."
  }

  assert {
    condition     = aws_flow_log.this[0].log_destination_type == "cloud-watch-logs"
    error_message = "Flow logs should be delivered to CloudWatch Logs."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].retention_in_days == 90
    error_message = "The flow log group must have a bounded retention period, not infinite retention."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow_log[0].name == "/aws/vpc-flow-log/unit-test-vpc"
    error_message = "The flow log group name should be namespaced per VPC."
  }
}

run "flow_log_role_is_least_privilege" {
  # The inline policy must name this VPC's own log group, never "*".
  assert {
    condition = !contains(
      jsondecode(aws_iam_role_policy.flow_log[0].policy).Statement[0].Resource,
      "*"
    )
    error_message = "The flow log role policy must not grant log writes on all resources."
  }

  assert {
    condition = alltrue([
      for action in jsondecode(aws_iam_role_policy.flow_log[0].policy).Statement[0].Action :
      startswith(action, "logs:")
    ])
    error_message = "The flow log role must only be granted CloudWatch Logs actions."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role.flow_log[0].assume_role_policy).Statement[0].Principal.Service
      == "vpc-flow-logs.amazonaws.com"
    )
    error_message = "Only the VPC flow logs service should be able to assume the role."
  }

  assert {
    condition = can(
      jsondecode(aws_iam_role.flow_log[0].assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceAccount"]
    )
    error_message = "The assume-role policy must carry an aws:SourceAccount confused-deputy guard."
  }
}

run "flow_logs_can_be_disabled" {
  variables {
    enable_flow_log = false
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "enable_flow_log = false must not create a flow log."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.flow_log) == 0
    error_message = "enable_flow_log = false must not create a log group."
  }

  assert {
    condition     = length(aws_iam_role.flow_log) == 0
    error_message = "enable_flow_log = false must not create an IAM role."
  }
}

run "rejects_invalid_traffic_type" {
  command = plan

  variables {
    flow_log_traffic_type = "EVERYTHING"
  }

  expect_failures = [var.flow_log_traffic_type]
}

run "rejects_invalid_retention" {
  command = plan

  variables {
    flow_log_retention_in_days = 45
  }

  expect_failures = [var.flow_log_retention_in_days]
}

run "rejects_invalid_aggregation_interval" {
  command = plan

  variables {
    flow_log_max_aggregation_interval = 300
  }

  expect_failures = [var.flow_log_max_aggregation_interval]
}

run "rejects_invalid_tenancy" {
  command = plan

  variables {
    instance_tenancy = "host"
  }

  expect_failures = [var.instance_tenancy]
}

run "rejects_malformed_cidr" {
  command = plan

  variables {
    cidr_block = "10.0.0.0"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_ipv6_cidr" {
  command = plan

  variables {
    cidr_block = "2001:db8::/32"
  }

  expect_failures = [var.cidr_block]
}

# AWS only accepts VPC CIDR prefixes from /16 to /28.
run "rejects_cidr_prefix_shorter_than_16" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/8"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_cidr_prefix_longer_than_28" {
  command = plan

  variables {
    cidr_block = "10.0.0.0/29"
  }

  expect_failures = [var.cidr_block]
}

run "accepts_smallest_allowed_cidr" {
  variables {
    cidr_block = "10.0.0.0/28"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/28"
    error_message = "A /28 is the smallest CIDR AWS allows and must be accepted."
  }
}

run "rejects_empty_name" {
  command = plan

  variables {
    name = "   "
  }

  expect_failures = [var.name]
}

# AWS cannot enable DNS hostnames on a VPC with DNS support disabled, and only
# says so after the VPC exists. The precondition surfaces it during plan.
run "rejects_dns_hostnames_without_dns_support" {
  command = plan

  variables {
    enable_dns_support   = false
    enable_dns_hostnames = true
  }

  expect_failures = [aws_vpc.this]
}

run "accepts_both_dns_attributes_disabled" {
  variables {
    enable_dns_support   = false
    enable_dns_hostnames = false
  }

  assert {
    condition     = !aws_vpc.this.enable_dns_support && !aws_vpc.this.enable_dns_hostnames
    error_message = "Turning both DNS attributes off is a valid combination and must be allowed."
  }
}
