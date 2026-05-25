output "domain_name" {
  description = "Nome do dominio OpenSearch."
  value       = aws_opensearch_domain.this.domain_name
}

output "domain_arn" {
  description = "ARN do dominio OpenSearch."
  value       = aws_opensearch_domain.this.arn
}

output "endpoint" {
  description = "Endpoint HTTPS do dominio OpenSearch (sem o prefixo https://)."
  value       = aws_opensearch_domain.this.endpoint
}

output "endpoint_url" {
  description = "URL completa HTTPS do dominio OpenSearch."
  value       = local.endpoint_url
}

output "engine_version" {
  description = "Versao do engine OpenSearch provisionado."
  value       = aws_opensearch_domain.this.engine_version
}

output "log_index" {
  description = "Prefixo do indice de logs configurado para o FluentBit."
  value       = var.log_index
}

output "fluentbit_output_config" {
  description = "Bloco de configuracao OUTPUT pronto para uso no modulo fluentbit-k8s (campo config.outputs)."
  value       = local.fluentbit_output_config
  sensitive   = true
}

output "grafana_datasource" {
  description = "Objeto compativel com module.grafana.opensearch_datasources para configurar o datasource no Grafana."
  value = {
    name             = var.domain_name
    uid              = replace(var.domain_name, "-", "_")
    url              = local.endpoint_url
    index            = "${var.log_index}-*"
    time_field       = "@timestamp"
    engine_version   = local.effective_engine_version
    basic_auth_user  = var.master_user.username
    is_default       = false
    editable         = true
    json_data        = {}
    secure_json_data = {}
  }
  sensitive = true
}
