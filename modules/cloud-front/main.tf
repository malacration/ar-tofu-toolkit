locals {
  full_name = "${var.project-name}-${var.cliente_name}-${var.environment}"
}

resource "aws_cloudfront_origin_access_control" "cloudfront_acl" {
  name = local.full_name

  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_identity" "s3_identity" {
  comment = "S3 CloudFront Origin Access Identity"
}


resource "aws_cloudfront_distribution" "distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = "S3-ar-${local.full_name}"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.full_name}"
  default_root_object = "index.html"
  aliases = var.full_dns_name != "" ? [var.full_dns_name] : []

  custom_error_response {
    error_code          = 404
    response_code       = 200
    response_page_path  = "/index.html"
  }

  default_cache_behavior {
    compress        = true
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-ar-${local.full_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn             = var.zone_id != "" ? "arn:aws:acm:us-east-1:459109365497:certificate/b79bee47-1cc2-4d2a-88b7-6803dd08debd" : null
    ssl_support_method              = var.zone_id != "" ? "sni-only" : null
    minimum_protocol_version        = var.zone_id != "" ? "TLSv1.2_2021" : null
    cloudfront_default_certificate  = var.zone_id != "" ? false : true
  }
  
  tags = {
    cliente = var.cliente_name
    cliente-group = var.cliente_group
    project = var.repo_name
    environment = var.environment
  }
}

output "s3_bucket" {
  value = aws_s3_bucket.bucket
}

output "progam-parans" {
  value = "${path.module}/scripts/download_release.sh ${var.release_version} ${var.repo_owner} ${var.repo_name} ${var.repo_name} ${var.github_token} ${local.full_name} ${var.path_adicional}"
}

output "all" {
  value = {
    dominio = var.zone_id == "" || var.full_dns_name == "" ? aws_cloudfront_distribution.distribution.domain_name : var.full_dns_name
    distPath = local.distPath
  }
  
}

# resource "null_resource" "invalidate_cache_cloudfront" {
#   triggers = {
#     release_version = var.release_version
#   }

#   provisioner "local-exec" {
#     command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.website_cdn.id} --paths '/*' --profile terraform"
#   }

#   depends_on = [aws_cloudfront_distribution.distribution, aws_s3_object.files, aws_s3_object.adicional_files]
# }