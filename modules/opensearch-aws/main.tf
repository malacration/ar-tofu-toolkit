data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_security_group" "opensearch" {
  count = local.vpc_mode ? 1 : 0

  name        = "${var.domain_name}-opensearch"
  description = "Security group para o dominio OpenSearch ${var.domain_name}"
  vpc_id      = var.network.vpc_id

  ingress {
    description = "HTTPS para o OpenSearch"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = length(var.network.allowed_cidr_blocks) > 0 ? var.network.allowed_cidr_blocks : ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_opensearch_domain" "this" {
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type  = var.instance.type
    instance_count = var.instance.count

    dedicated_master_enabled = var.instance.dedicated_master
    dedicated_master_type    = var.instance.dedicated_master ? var.instance.master_type : null
    dedicated_master_count   = var.instance.dedicated_master ? var.instance.master_count : null

    zone_awareness_enabled = var.instance.zone_awareness

    dynamic "zone_awareness_config" {
      for_each = var.instance.zone_awareness ? [1] : []
      content {
        availability_zone_count = var.instance.availability_zones
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.storage.volume_type
    volume_size = var.storage.volume_size
    iops        = var.storage.iops
    throughput  = var.storage.throughput
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.master_user.username
      master_user_password = var.master_user.password
    }
  }

  dynamic "vpc_options" {
    for_each = local.vpc_mode ? [1] : []
    content {
      subnet_ids         = var.network.subnet_ids
      security_group_ids = concat(
        [aws_security_group.opensearch[0].id],
        var.network.additional_security_group_ids
      )
    }
  }

  tags = var.tags
}

resource "aws_opensearch_domain_policy" "this" {
  domain_name = aws_opensearch_domain.this.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "es:*"
        Resource  = "${aws_opensearch_domain.this.arn}/*"
      }
    ]
  })
}
