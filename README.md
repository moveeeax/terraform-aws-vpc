# terraform-aws-vpc

Terraform module that manages an [Amazon VPC](https://aws.amazon.com/vpc/). It
creates a single VPC with configurable CIDR block, tenancy and DNS behaviour,
sane private-by-default settings and consistent tagging.

Two things AWS gets wrong out of the box are corrected by default:

- **The default security group is emptied.** Every new VPC ships with a default
  security group that allows all traffic between its members and unrestricted
  egress to `0.0.0.0/0`. This module adopts it and revokes every rule, which is
  the state CIS AWS Foundations 5.4 asks for. Set
  `manage_default_security_group = false` to leave it alone.
- **Flow logs are turned on.** AWS records no network telemetry for a VPC unless
  you ask. This module creates a per-VPC CloudWatch log group with 90-day
  retention plus a least-privilege IAM role scoped to that log group. Set
  `enable_flow_log = false` to opt out.

Both defaults create resources that cost money (a CloudWatch log group and its
ingested data) or change behaviour of existing workloads (anything still relying
on the default security group). Review a `terraform plan` before upgrading an
existing deployment.

## Usage

```hcl
module "vpc" {
  source = "github.com/moveeeax/terraform-aws-vpc"

  name       = "prod-vpc"
  cidr_block = "10.0.0.0/16"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Input validation

Inputs that AWS would otherwise reject partway through an apply are checked
during `terraform plan` instead:

- `cidr_block` must be a valid IPv4 CIDR with a prefix length between `/16` and
  `/28` — the range `CreateVpc` accepts.
- `enable_dns_hostnames` may only be `true` when `enable_dns_support` is also
  `true`. AWS enforces this in `ModifyVpcAttribute`, which runs *after* the VPC
  has been created, so the invalid combination would otherwise leave a
  half-applied VPC behind.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.0   |

## Inputs

| Name                                | Description                                                                               | Type          | Default         | Required |
|-------------------------------------|-------------------------------------------------------------------------------------------|---------------|-----------------|:--------:|
| `name`                              | Name tag applied to the VPC, and the basis for derived resource names. Must be non-empty. | `string`      | n/a             |   yes    |
| `cidr_block`                        | IPv4 CIDR block for the VPC. Prefix length must be between `/16` and `/28`.               | `string`      | `"10.0.0.0/16"` |    no    |
| `instance_tenancy`                  | Tenancy of instances launched into the VPC (`default` or `dedicated`).                    | `string`      | `"default"`     |    no    |
| `enable_dns_support`                | Whether DNS resolution is supported for the VPC.                                          | `bool`        | `true`          |    no    |
| `enable_dns_hostnames`              | Whether instances receive public DNS hostnames.                                           | `bool`        | `true`          |    no    |
| `manage_default_security_group`     | Adopt the VPC's default security group and revoke all of its ingress and egress rules.    | `bool`        | `true`          |    no    |
| `enable_flow_log`                   | Record VPC flow logs to a dedicated CloudWatch log group.                                 | `bool`        | `true`          |    no    |
| `flow_log_traffic_type`             | Traffic captured in flow logs (`ACCEPT`, `REJECT` or `ALL`).                              | `string`      | `"ALL"`         |    no    |
| `flow_log_retention_in_days`        | Retention of the flow log group in days; `0` retains forever.                             | `number`      | `90`            |    no    |
| `flow_log_kms_key_arn`              | KMS key ARN encrypting the flow log group; defaults to the AWS-owned CloudWatch Logs key. | `string`      | `null`          |    no    |
| `flow_log_max_aggregation_interval` | Seconds packets are aggregated into one flow log record (`60` or `600`).                  | `number`      | `600`           |    no    |
| `tags`                              | Tags applied to every resource this module creates.                                       | `map(string)` | `{}`            |    no    |

## Outputs

| Name                                 | Description                                                          |
|--------------------------------------|----------------------------------------------------------------------|
| `id`                                 | ID of the VPC.                                                       |
| `arn`                                | ARN of the VPC.                                                      |
| `cidr_block`                         | IPv4 CIDR block of the VPC.                                          |
| `default_security_group_id`          | ID of the default security group created with the VPC.               |
| `default_route_table_id`             | ID of the default route table created with the VPC.                  |
| `main_route_table_id`                | ID of the main route table associated with the VPC.                  |
| `flow_log_id`                        | ID of the VPC flow log, or `null` when disabled.                     |
| `flow_log_cloudwatch_log_group_name` | Name of the log group receiving flow logs, or `null` when disabled.  |
| `flow_log_cloudwatch_log_group_arn`  | ARN of the log group receiving flow logs, or `null` when disabled.   |
| `flow_log_iam_role_arn`              | ARN of the role the flow log service assumes, or `null` when disabled.|

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test          # mocked provider, no AWS credentials needed
tflint --init && tflint --recursive
```

`terraform test` uses `mock_provider`, which needs Terraform (or OpenTofu) 1.7
or newer. The module itself still supports 1.5 — that requirement applies to the
test suite only.

## License

[MIT](LICENSE)
