variable "name" {
  description = "Nome base do ambiente (ex.: energia-fatura-sheet)"
  type        = string
}

variable "dns_host" {
  description = "Hostname completo que deve apontar para o CloudFront (ex.: app.exemplo.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "Hosted-Zone ID do domínio em que o dns_host será criado"
  type        = string
}