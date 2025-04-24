locals {
    bucket_prod       = "ar-${var.name}-production"
    bucket_hmg        = "ar-${var.name}-hmg"
    state_object_key  = "${var.name}-tfstate"
    bucket-tf-state   = "ar-tofu-state"
}

/* ---------- IAM user + access key --------------------------------------- */
resource "aws_iam_user" "site" {
  name = "${var.name}"
}

resource "aws_iam_access_key" "site" {
  user = aws_iam_user.site.name
}

resource "aws_iam_user_login_profile" "site" {
  user = aws_iam_user.site.name
  password_reset_required           = true
}


data "aws_iam_policy_document" "site" {
  # Acesso total aos buckets "ar-{name}-{env}"
  statement {
    sid     = "FullAccessSiteBuckets"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.bucket_prod}",
      "arn:aws:s3:::${local.bucket_prod}/*",
      "arn:aws:s3:::${local.bucket_hmg}",
      "arn:aws:s3:::${local.bucket_hmg}/*",
    ]
  }

  statement {
    sid     = "AllowReadOnlyTaggedBuckets"
    effect  = "Allow"
    actions = [
        "s3:GetObject",
        "s3:ListBucket"
    ]
    resources = [
        "arn:aws:s3:::*",
        "arn:aws:s3:::*/*"
    ]
    condition {
        test     = "StringEquals"
        variable = "s3:ResourceTag/projeto"
        values   = [var.name]
    }
  }

  # Acesso direto ao tfstate
  statement {
    sid     = "TfStateAccess"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::ar-tofu-state/${local.state_object_key}"]
  }

  # Permissão para modificar entrada DNS específica no Route53
  statement {
    sid     = "AllowSpecificDnsChange"
    effect  = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.route53_zone_id}"]
    condition {
      test     = "StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordNames"
      values   = [var.dns_host]
    }
  }

  # Permissão para criar CloudFront com nome esperado
  statement {
    sid     = "AllowCreateExpectedCloudFront"
    effect  = "Allow"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "cloudfront:Comment"
      values   = [
        "${var.name}-production",
        "${var.name}-hmg"
      ]
    }
  }
  
  statement {
    sid     = "ConsoleLoginSupport"
    effect  = "Allow"
    actions = [
      "iam:ChangePassword"
    ]
    resources = ["arn:aws:iam::*:user/${aws_iam_user.site.name}"]
  }
}

resource "aws_iam_user_policy" "site" {
  user   = aws_iam_user.site.name
  policy = data.aws_iam_policy_document.site.json
}