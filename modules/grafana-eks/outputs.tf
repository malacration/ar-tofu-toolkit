output "namespace" {
  description = "Namespace onde o Grafana foi instalado."
  value       = helm_release.grafana.namespace
}

output "helm_release_name" {
  description = "Nome do release Helm do Grafana."
  value       = helm_release.grafana.name
}

output "chart_version" {
  description = "Versao do chart Helm instalada."
  value       = helm_release.grafana.version
}

output "service_host" {
  description = "DNS interno do service do Grafana no cluster Kubernetes."
  value       = "${helm_release.grafana.name}.${var.namespace}.svc.cluster.local"
}

output "service_port" {
  description = "Porta HTTP do service do Grafana."
  value       = var.service.port
}

output "URL" {
  description = "URL HTTP externa do Grafana. Este modulo nao faz descoberta automatica; configure exposicao fora dele."
  value       = null
}

output "url" {
  description = "Alias temporario para URL. Este modulo nao faz descoberta automatica."
  value       = null
}

output "url_internal" {
  description = "URL HTTP interna do Grafana dentro do cluster Kubernetes."
  value       = "http://${helm_release.grafana.name}.${var.namespace}.svc.cluster.local:${var.service.port}"
}

output "loki_datasource_names" {
  description = "Nomes dos datasources Loki provisionados."
  value       = [for datasource in var.loki_datasources : datasource.name]
}

output "loki_datasource_uids" {
  description = "UIDs dos datasources Loki provisionados."
  value       = [for datasource in var.loki_datasources : datasource.uid]
}

output "loki_datasource_name" {
  description = "Alias de compatibilidade para o nome do primeiro datasource Loki provisionado."
  value       = try(var.loki_datasources[0].name, null)
}

output "loki_datasource_uid" {
  description = "Alias de compatibilidade para o UID do primeiro datasource Loki provisionado."
  value       = try(var.loki_datasources[0].uid, null)
}

output "opensearch_datasource_names" {
  description = "Nomes dos datasources OpenSearch provisionados."
  value       = [for ds in var.opensearch_datasources : ds.name]
  sensitive   = true
}

output "opensearch_datasource_uids" {
  description = "UIDs dos datasources OpenSearch provisionados."
  value       = [for ds in var.opensearch_datasources : ds.uid]
  sensitive   = true
}

output "plugins" {
  description = "Lista de plugins instalados no Grafana por este modulo."
  value       = local.plugins_list
}

output "ingress_hostname" {
  description = "Hostname do ALB gerado pelo Ingress. Null quando ingress.enabled = false."
  value       = var.ingress.enabled ? try(kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].hostname, null) : null
}

output "alb_rule_arn" {
  description = "ARN da listener rule criada no ALB existente. Null quando alb_rule.enabled = false."
  value       = local.use_alb_rule ? try(aws_lb_listener_rule.grafana[0].arn, null) : null
}

output "sso_enabled" {
  description = "Indica se o SSO via Keycloak foi configurado."
  value       = local.sso_enabled
  sensitive   = true
}

output "sso_keycloak_instructions" {
  description = "Mini instrucao para configurar o Keycloak para autenticacao no Grafana."
  value       = local.sso_keycloak_instructions
  sensitive   = true
}
