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
