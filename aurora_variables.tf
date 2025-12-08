# Copyright (c) 2025 Hammerspace, Inc
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# -----------------------------------------------------------------------------
# Aurora module for Project Houston
# ---------------------------------
# This module creates:
#   - A security group for Aurora
#   - An RDS DB subnet group
#   - An Aurora (PostgreSQL/MySQL) cluster
#   - N Aurora cluster instances
#
# VPC and subnets are expected to be created by the root module.
# Pass in vpc_id and the private subnet IDs.
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name for tagging and resource naming"
  type        = string
}

variable "region" {
  description = "AWS region for the Aurora cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which to place the Aurora resources"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for the Aurora DB subnet group (min 2 AZs recommended)"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "Primary VPC CIDR, used to allow internal access to Aurora"
  type        = string
  default     = null
}

variable "allowed_source_cidr_blocks" {
  description = "Additional IPv4 CIDRs allowed to connect to Aurora (e.g., corporate VPN, bastion, etc.)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags for all Aurora resources"
  type        = map(string)
  default     = {}
}

# -------------------------------------------------------------------
# Aurora engine & sizing
# -------------------------------------------------------------------

variable "engine" {
  description = "Aurora engine. Common values: aurora-postgresql, aurora-mysql"
  type        = string
  default     = "aurora-postgresql"

  validation {
    condition = contains(["aurora-postgresql", "aurora-mysql"], var.engine)
    error_message = "engine must be one of: aurora-postgresql, aurora-mysql."
  }
}

variable "engine_version" {
  description = "Aurora engine version (optional). If empty, AWS chooses a default."
  type        = string
  default     = "15.3"
}

variable "instance_class" {
  description = "Aurora instance class (e.g., db.r6g.large, db.r7g.large)"
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of Aurora instances in the cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "db_name" {
  description = "Initial database name in the Aurora cluster"
  type        = string
  default     = "projecthouston"
}

variable "master_username" {
  description = "Master username for Aurora"
  type        = string
}

variable "master_password" {
  description = "Master password for Aurora"
  type        = string
  sensitive   = true
}

# -------------------------------------------------------------------
# Durability, backups, maintenance
# -------------------------------------------------------------------

variable "backup_retention_days" {
  description = "How many days to retain automated backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window (UTC), e.g. 04:00-05:00"
  type        = string
  default     = "04:00-05:00"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window (UTC), e.g. sun:06:00-sun:07:00"
  type        = string
  default     = "sun:06:00-sun:07:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection on the Aurora cluster"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Encrypt Aurora storage"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID/ARN for encryption. If empty and storage_encrypted=true, AWS default KMS key is used."
  type        = string
  default     = ""
}

# -------------------------------------------------------------------
# Performance Insights
# -------------------------------------------------------------------

variable "enable_performance_insights" {
  description = "Enable Performance Insights for Aurora instances"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention in days (7, 731, or 1095 typically)"
  type        = number
  default     = 7
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ID/ARN for Performance Insights (optional)"
  type        = string
  default     = ""
}

# Enable the http endpoint for API access

variable "enable_http_endpoint" {
  description = "Enable the Aurora Data API (HTTP endpoint) for the cluster."
  type	      = bool
  default     = false
}
