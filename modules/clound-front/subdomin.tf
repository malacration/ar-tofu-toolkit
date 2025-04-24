

resource "aws_route53_record" "cloudfront_cname" {
  count   = var.zone_id != "" && var.full_dns_name != "" ? 1 : 0
  zone_id = var.zone_id
  name    = var.full_dns_name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = true
  }
}