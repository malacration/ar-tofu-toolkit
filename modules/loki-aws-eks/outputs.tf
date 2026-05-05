output "cluster_name" {
  description = "Nome do cluster EKS validado pelo modulo."
  value       = data.aws_eks_cluster.this.name
}

output "namespace" {
  description = "Namespace onde o Loki foi instalado."
  value       = var.namespace
}

output "helm_release_name" {
  description = "Nome do release Helm do Loki."
  value       = helm_release.loki.name
}

output "gateway_service_host" {
  description = "DNS interno do service gateway do Loki no cluster Kubernetes."
  value       = "${helm_release.loki.name}-gateway.${var.namespace}.svc.cluster.local"
}

output "gateway_service_port" {
  description = "Porta HTTP do service gateway do Loki."
  value       = 80
}

output "chunks_bucket_name" {
  description = "Bucket S3 usado para chunks do Loki."
  value       = var.storage.bucket_name
}

output "ruler_bucket_name" {
  description = "Bucket S3 usado pelo ruler do Loki."
  value       = local.ruler_bucket_name
}

output "iam_user_name" {
  description = "Usuario IAM criado para o Loki quando o modulo gera as credenciais."
  value       = local.create_credentials ? aws_iam_user.loki[0].name : null
}

output "generated_access_key_id" {
  description = "Access key id criado pelo modulo quando s3_auth.create_credentials = true."
  value       = local.create_credentials ? aws_iam_access_key.loki[0].id : null
  sensitive   = true
}

output "aws_account_id" {
  description = "Conta AWS usada pelo provider."
  value       = data.aws_caller_identity.current.account_id
}

output "name" {
  description = "Nome sugerido para o datasource do Loki no Grafana."
  value = var.eks_cluster_name
}

output "grafana_datasource" {
  description = "Objeto compativel com module.grafana.loki_datasources com os dados efetivamente conhecidos por este modulo."
  value = {
    name             = var.eks_cluster_name
    uid              = null
    url              = "http://${helm_release.loki.name}-gateway.${var.namespace}.svc.cluster.local:80"
    is_default       = true
    editable         = true
    json_data = {
      httpHeaderName1 = "X-Scope-OrgID"
    }
    secure_json_data = {
      httpHeaderValue1 = var.grafana_tenant_id
    }
  }
}

output "grafana_tenant_id" {
  description = "Tenant ID default exposto para integracoes como o datasource do Grafana."
  value       = var.grafana_tenant_id
}
