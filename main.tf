resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  instance_tenancy     = var.instance_tenancy
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(var.tags, { Name = var.name })

  # AWS refuses to enable DNS hostnames on a VPC whose DNS support is off, and
  # it refuses at ModifyVpcAttribute time — after the VPC has already been
  # created. Since enable_dns_hostnames defaults to true, flipping only
  # enable_dns_support to false is an easy way to hit that half-applied state.
  lifecycle {
    precondition {
      condition     = var.enable_dns_support || !var.enable_dns_hostnames
      error_message = "enable_dns_hostnames requires enable_dns_support to be true; AWS will not enable DNS hostnames on a VPC with DNS support turned off."
    }
  }
}

# AWS creates a default security group with every VPC that allows all traffic
# between its own members and unrestricted egress to 0.0.0.0/0. Declaring the
# resource with no ingress/egress blocks revokes every rule, which is the
# hardened state recommended by CIS AWS Foundations 5.4. Workloads should use
# purpose-built security groups instead of the default one.
resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-default" })
}
