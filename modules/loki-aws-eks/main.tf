data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "chunks" {
  count = local.create_bucket ? 1 : 0

  bucket        = var.storage.bucket_name
  force_destroy = var.storage.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket" "ruler" {
  count = local.create_bucket && local.create_secondary_bucket ? 1 : 0

  bucket        = local.ruler_bucket_name
  force_destroy = var.storage.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "chunks" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.chunks[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "ruler" {
  count = local.create_bucket && local.create_secondary_bucket ? 1 : 0

  bucket = aws_s3_bucket.ruler[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "chunks" {
  count = local.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.chunks[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ruler" {
  count = local.create_bucket && local.create_secondary_bucket ? 1 : 0

  bucket = aws_s3_bucket.ruler[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_user" "loki" {
  count = local.create_credentials ? 1 : 0

  name = local.created_iam_user_name
  path = "/"

  tags = local.common_tags
}

resource "aws_iam_policy" "loki_s3" {
  count = local.create_credentials ? 1 : 0

  name = local.created_iam_policy_name
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LokiBucketMetadata"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
        ]
        Resource = [
          "arn:aws:s3:::${var.storage.bucket_name}",
          "arn:aws:s3:::${local.ruler_bucket_name}",
        ]
      },
      {
        Sid    = "LokiObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = [
          "arn:aws:s3:::${var.storage.bucket_name}/*",
          "arn:aws:s3:::${local.ruler_bucket_name}/*",
        ]
      },
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_user_policy_attachment" "loki_s3" {
  count = local.create_credentials ? 1 : 0

  user       = aws_iam_user.loki[0].name
  policy_arn = aws_iam_policy.loki_s3[0].arn
}

resource "aws_iam_access_key" "loki" {
  count = local.create_credentials ? 1 : 0

  user = aws_iam_user.loki[0].name
}

resource "helm_release" "loki" {
  name             = var.helm_release_name
  repository       = var.chart.repository
  chart            = var.chart.name
  version          = var.chart.version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [
    yamlencode(local.generated_values),
    yamlencode(var.values_override),
  ]

  depends_on = [
    aws_s3_bucket.chunks,
    aws_s3_bucket.ruler,
    aws_iam_user_policy_attachment.loki_s3,
  ]

  lifecycle {
    precondition {
      condition     = local.create_bucket ? local.create_credentials : true
      error_message = "Quando storage.create_bucket = true, s3_auth.create_credentials tambem deve ser true."
    }

    precondition {
      condition     = local.create_bucket ? true : !local.create_credentials
      error_message = "Quando storage.create_bucket = false, s3_auth.create_credentials deve ser false."
    }

    precondition {
      condition     = local.create_credentials ? true : try(var.s3_auth.existing.access_key_id != "" && var.s3_auth.existing.secret_access_key != "", false)
      error_message = "Quando s3_auth.create_credentials = false, informe s3_auth.existing.access_key_id e s3_auth.existing.secret_access_key."
    }
  }
}
