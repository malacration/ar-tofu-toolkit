locals {
  full_dns_name = "${var.sub-domain}.${var.domain}"
}

data "aws_instance" "instancia"{
    instance_id = var.instance_id_ec2
}

data "aws_subnet" "da_instancia" {
  id = data.aws_instance.instancia.subnet_id
}

data "aws_acm_certificate" "this" {
  domain       = "*.${var.domain}"
  statuses     = ["ISSUED"]
  most_recent  = true
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

resource "aws_security_group" "web-public" {
  name        = "CloudFront-${var.sub-domain}.${var.domain}"
  description = "For your cloudfront - ${var.sub-domain}.${var.domain}"
  vpc_id      = data.aws_subnet.da_instancia.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "web-public-443" {
    security_group_id = aws_security_group.web-public.id
    cidr_ipv4         = "0.0.0.0/0"
    from_port         = 443
    to_port           = 443
    ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "web-public-80" {
    security_group_id = aws_security_group.web-public.id
    cidr_ipv4         = "0.0.0.0/0"
    from_port         = 80
    to_port           = 80
    ip_protocol       = "tcp"
}

resource "aws_network_interface_sg_attachment" "extra" {
  security_group_id    = aws_security_group.web-public.id
  network_interface_id = data.aws_instance.instancia.network_interface_id
}

resource "aws_cloudfront_distribution" "cf_ec2" {
    enabled         = true
    is_ipv6_enabled = true
    aliases = [local.full_dns_name]
    price_class = "PriceClass_100"

    origin {
        origin_id   = "ec2Origin"
        domain_name = data.aws_instance.instancia.public_dns
        custom_origin_config {
            origin_protocol_policy = var.origin_protocol_policy
            http_port              = 80
            https_port             = 443
            origin_ssl_protocols   = ["TLSv1.2"]
        }
    }
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    default_cache_behavior {
        target_origin_id        = "ec2Origin"
        viewer_protocol_policy  = "redirect-to-https"
        allowed_methods         = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods           = ["HEAD", "GET"]
        
        cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
        origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
        
        min_ttl     = 0
        default_ttl = 0
        max_ttl     = 0
    }

    # viewer_certificate {
    #     acm_certificate_arn             = var.zone_id != "" ? "arn:aws:acm:us-east-1:459109365497:certificate/b79bee47-1cc2-4d2a-88b7-6803dd08debd" : null
    #     ssl_support_method              = var.zone_id != "" ? "sni-only" : null
    #     minimum_protocol_version        = var.zone_id != "" ? "TLSv1.2_2021" : null
    #     cloudfront_default_certificate  = var.zone_id != "" ? false : true
    # }

    viewer_certificate {
        acm_certificate_arn            = data.aws_acm_certificate.this.arn
        ssl_support_method             = "sni-only"
        minimum_protocol_version       = "TLSv1.2_2021"
    }
}


resource "aws_route53_record" "app_cf" {
  zone_id = var.zone_id
  name    = local.full_dns_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cf_ec2.domain_name
    zone_id                = aws_cloudfront_distribution.cf_ec2.hosted_zone_id
    evaluate_target_health = false
  }
}