variable "name" {
  description = "Name tag applied to the VPC, and the basis for derived resource names."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty; it is used to build the flow log group and IAM role names."
  }

  # var.name is spliced verbatim into the flow log CloudWatch log group name
  # ("/aws/vpc-flow-log/${var.name}") and the flow log IAM role's name_prefix.
  # Both AWS APIs reject characters outside this set — including plain spaces
  # — but only at apply time (CreateLogGroup / CreateRole), well after this
  # module's other validations would have caught a bad name. The set below is
  # the intersection of what each API allows: CloudWatch Logs additionally
  # allows "/" and "#", and IAM additionally allows "+ = , @", but neither
  # accepts the other's extras, so only their common subset is safe here.
  # Checking it turns a failed apply into a failed plan.
  validation {
    condition     = can(regex("^[\\w.-]+$", var.name))
    error_message = "name may only contain letters, digits, underscores, hyphens and dots; it is used verbatim in the flow log CloudWatch log group name and IAM role name, and both reject other characters (including spaces, slashes and \"@\") at apply time."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC. AWS accepts prefix lengths from /16 to /28."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be a valid IPv4 CIDR block, for example 10.0.0.0/16."
  }

  # AWS rejects a VPC CIDR outside /16../28 at CreateVpc time. Catching it here
  # turns a failed apply into a failed plan.
  validation {
    condition     = can(regex("/(1[6-9]|2[0-8])$", var.cidr_block))
    error_message = "cidr_block must have a prefix length between /16 and /28; AWS rejects VPC CIDR blocks outside that range."
  }
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

  # A malformed value here passes plan and fails at CreateLogGroup with an
  # opaque InvalidParameterException. Checking the ARN shape during plan
  # gives a precise error instead.
  validation {
    condition     = var.flow_log_kms_key_arn == null || can(regex("^arn:[^:]+:kms:[^:]+:\\d{12}:key/.+$", var.flow_log_kms_key_arn))
    error_message = "flow_log_kms_key_arn must be null or a KMS key ARN, for example arn:aws:kms:us-east-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab."
  }
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
