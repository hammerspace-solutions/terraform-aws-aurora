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
# modules/aurora/aurora_main.tf - Aurora module for Project Houston
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

# Lowercase the project name for those resources that require it

locals {
  project_name_lower    = "${lower(var.project_name)}"
}

# Do we need aurora events?

locals {
  aurora_events_email   = trimspace(var.event_email)
  aurora_events_enabled = local.aurora_events_email != ""
}

# Security Group for Aurora
resource "aws_security_group" "aurora_sg" {
  name        = "${var.project_name}-aurora-sg"
  description = "Security group for Aurora cluster"
  vpc_id      = var.vpc_id

  # Allow inbound from entire VPC CIDR + any extra CIDRs the root passes down
  ingress {
    from_port   = 5432
    to_port	= 5432
    protocol	= "tcp"
    cidr_blocks = concat(
      [data.aws_vpc.this.cidr_block],
      var.allowed_source_cidr_blocks,
    )
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-sg"
  })
}

# DB Subnet Group for Aurora
resource "aws_db_subnet_group" "aurora_subnets" {
  name       = "${local.project_name_lower}-aurora-subnet-group"
  subnet_ids = [var.subnet_1_id, var.subnet_2_id]

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-subnet-group"
  })
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${lower.project_name_lower}-aurora-cluster"

  engine         = var.engine
  engine_version = length(var.engine_version) > 0 ? var.engine_version : null
  enable_http_endpoint = var.enable_http_endpoint
  
  database_name   = var.db_name
  master_username = var.master_username
  master_password = var.master_password

  db_subnet_group_name   = aws_db_subnet_group.aurora_subnets.name
  vpc_security_group_ids = [aws_security_group.aurora_sg.id]

  backup_retention_period   = var.backup_retention_days
  preferred_backup_window   = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  storage_encrypted = var.storage_encrypted
  kms_key_id        = length(var.kms_key_id) > 0 ? var.kms_key_id : null

  deletion_protection = var.deletion_protection

  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  copy_tags_to_snapshot = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-cluster"
  })
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = var.instance_count
  identifier         = "${lower.project_name_lower}-aurora-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id

  engine         = var.engine
  engine_version = length(var.engine_version) > 0 ? var.engine_version : null

  instance_class      = var.instance_class
  publicly_accessible = false

  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id       = var.enable_performance_insights && length(var.performance_insights_kms_key_id) > 0 ? var.performance_insights_kms_key_id : null

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-${count.index + 1}"
  })
}

# -------------------------------------------------------------------
# Optional: Aurora/RDS event notifications via SNS + email
# Created only if aurora_event_email is non-empty
# -------------------------------------------------------------------

resource "aws_sns_topic" "aurora_events" {
  count = local.aurora_events_enabled ? 1 : 0

  name = "${local.project_name_lower}-aurora-events"

  tags = merge(
    var.tags,
    {
      Name = "${local.project_name_lower}-aurora-events"
    }
  )
}

resource "aws_sns_topic_subscription" "aurora_events_email" {
  count = local.aurora_events_enabled ? 1 : 0

  topic_arn = aws_sns_topic.aurora_events[0].arn
  protocol  = "email"
  endpoint  = local.aurora_events_email
}

resource "aws_db_event_subscription" "aurora_events" {
  count = local.aurora_events_enabled ? 1 : 0

  name      = "${local.project_name_lower}-aurora-events"
  sns_topic = aws_sns_topic.aurora_events[0].arn

  source_type = "db-cluster"
  source_ids  = [aws_rds_cluster.aurora.id]

  # Tweak event categories as you like
  event_categories = [
    "availability",
    "backup",
    "configuration change",
    "failure",
    "maintenance",
  ]

  enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${local.project_name_lower}-aurora-events"
    }
  )
}
