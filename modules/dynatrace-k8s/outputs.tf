output "namespace" {
  description = "Namespace onde o Dynatrace Operator foi instalado."
  value       = var.namespace
}

output "helm_release_name" {
  description = "Nome do release Helm do Dynatrace Operator."
  value       = helm_release.dynatrace_operator.name
}

output "dynakube_name" {
  description = "Nome do recurso DynaKube criado."
  value       = var.dynakube_name
}

output "tokens_secret_name" {
  description = "Nome do secret com os tokens usados pelo Dynatrace."
  value       = kubernetes_secret_v1.tokens.metadata[0].name
}

output "cluster_name" {
  description = "Nome do cluster exibido no Dynatrace."
  value       = var.cluster_name
}

output "tenant_url" {
  description = "URL do tenant Dynatrace configurada no DynaKube."
  value       = var.tenant_url
}
