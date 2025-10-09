output "all" {
  value = {
    dominio = "${var.sub-domain}.${var.domain}"
    https = "https://${var.sub-domain}.${var.domain}"
    instance_url = data.aws_instance.instancia.public_dns
    public_ip = data.aws_instance.instancia.public_ip
  }
}