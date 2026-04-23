output "namespace" {
  description = "Namespace onde o Fluent Bit foi instalado."
  value       = helm_release.fluentbit.namespace
}

output "helm_release_name" {
  description = "Nome do release Helm do Fluent Bit."
  value       = helm_release.fluentbit.name
}

output "chart_version" {
  description = "Versao do chart Helm instalada."
  value       = helm_release.fluentbit.version
}
