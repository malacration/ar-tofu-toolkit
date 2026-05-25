output "eks_cluster_name" {
  description = "Nome do cluster EKS usado pelo modulo."
  value       = data.aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS resolvido pelo modulo."
  value       = data.aws_eks_cluster.this.endpoint
}

output "aws_region" {
  description = "Regiao AWS efetiva usada para resolver o cluster EKS."
  value       = local.effective_region
}

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
