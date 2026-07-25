variable "name" {
  description = "Name tag applied to the VPC."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_tenancy" {
  description = "Tenancy of instances launched into the VPC. Either default or dedicated."
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "instance_tenancy must be either default or dedicated."
  }
}

variable "enable_dns_support" {
  description = "Whether DNS resolution is supported for the VPC."
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether instances receive public DNS hostnames."
  type        = bool
  default     = true
}

variable "manage_default_security_group" {
  description = <<-EOT
    Whether to adopt the VPC's default security group and strip every ingress
    and egress rule from it. Leaving the default security group untouched means
    it permits unrestricted egress and all traffic between its members.
  EOT
  type        = bool
  default     = true
}

variable "enable_flow_log" {
  description = "Whether to record VPC flow logs to a dedicated CloudWatch log group."
  type        = bool
  default     = true
}

variable "flow_log_traffic_type" {
  description = "Which traffic to capture in flow logs. One of ACCEPT, REJECT or ALL."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be one of ACCEPT, REJECT or ALL."
  }
}

variable "flow_log_retention_in_days" {
  description = "Retention of the flow log CloudWatch log group, in days. Use 0 to retain forever."
  type        = number
  default     = 90

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.flow_log_retention_in_days
    )
    error_message = "flow_log_retention_in_days must be one of the retention periods CloudWatch Logs accepts."
  }
}

variable "flow_log_kms_key_arn" {
  description = "ARN of a KMS key used to encrypt the flow log group. Defaults to CloudWatch Logs' AWS-owned key."
  type        = string
  default     = null
}

variable "flow_log_max_aggregation_interval" {
  description = "Maximum seconds during which packets are aggregated into one flow log record. Either 60 or 600."
  type        = number
  default     = 600

  validation {
    condition     = contains([60, 600], var.flow_log_max_aggregation_interval)
    error_message = "flow_log_max_aggregation_interval must be either 60 or 600."
  }
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}
