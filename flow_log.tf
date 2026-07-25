# VPC flow logs are off by default in AWS, which leaves no record of accepted or
# rejected traffic for incident response. This module turns them on by default
# and ships the records to a dedicated, retention-bounded CloudWatch log group.

locals {
  flow_log_name_prefix = "${var.name}-flow-log-"
}

data "aws_caller_identity" "current" {
  count = var.enable_flow_log ? 1 : 0
}

data "aws_partition" "current" {
  count = var.enable_flow_log ? 1 : 0
}

resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name              = "/aws/vpc-flow-log/${var.name}"
  retention_in_days = var.flow_log_retention_in_days
  kms_key_id        = var.flow_log_kms_key_arn

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  # IAM caps name_prefix at 38 characters so its generated suffix still fits.
  name_prefix = substr(local.flow_log_name_prefix, 0, min(38, length(local.flow_log_name_prefix)))

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }

      # Guard against the confused-deputy problem: only flow logs owned by this
      # account, in this partition, may assume the role.
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current[0].partition}:ec2:*:${data.aws_caller_identity.current[0].account_id}:vpc-flow-log/*"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name_prefix = "flow-log-"
  role        = aws_iam_role.flow_log[0].id

  # Scoped to this VPC's own log group rather than the "Resource": "*" that the
  # AWS documentation example hands out.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      Resource = [
        aws_cloudwatch_log_group.flow_log[0].arn,
        "${aws_cloudwatch_log_group.flow_log[0].arn}:*",
      ]
    }]
  })
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_log ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = var.flow_log_traffic_type
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_log[0].arn
  iam_role_arn             = aws_iam_role.flow_log[0].arn
  max_aggregation_interval = var.flow_log_max_aggregation_interval

  tags = merge(var.tags, { Name = "${var.name}-flow-log" })

  # The role must be allowed to write before the service starts delivering.
  depends_on = [aws_iam_role_policy.flow_log]
}
