output "id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "arn" {
  description = "ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "cidr_block" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "default_security_group_id" {
  description = "ID of the default security group created with the VPC."
  value       = aws_vpc.this.default_security_group_id
}

output "default_route_table_id" {
  description = "ID of the default route table created with the VPC."
  value       = aws_vpc.this.default_route_table_id
}

output "main_route_table_id" {
  description = "ID of the main route table associated with the VPC."
  value       = aws_vpc.this.main_route_table_id
}

output "flow_log_id" {
  description = "ID of the VPC flow log, or null when flow logs are disabled."
  value       = one(aws_flow_log.this[*].id)
}

output "flow_log_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group receiving flow logs, or null when flow logs are disabled."
  value       = one(aws_cloudwatch_log_group.flow_log[*].name)
}

output "flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group receiving flow logs, or null when flow logs are disabled."
  value       = one(aws_cloudwatch_log_group.flow_log[*].arn)
}

output "flow_log_iam_role_arn" {
  description = "ARN of the IAM role the flow log service assumes, or null when flow logs are disabled."
  value       = one(aws_iam_role.flow_log[*].arn)
}
