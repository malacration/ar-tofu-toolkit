
data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", var.eks_cluster_name,
      "--region", coalesce(var.aws_region, data.aws_region.current.id),
    ]
  }
}

module "dynatrace_k8s" {
  source = "../dynatrace-k8s"

  cluster_name                 = local.effective_cluster_name
  tenant_url                   = var.tenant_url
  tokens                       = var.tokens
  namespace                    = var.namespace
  create_namespace             = var.create_namespace
  helm_release_name            = var.helm_release_name
  dynakube_name                = var.dynakube_name
  chart                        = var.chart
  activegate_capabilities      = var.activegate_capabilities
  enable_kubernetes_monitoring = var.enable_kubernetes_monitoring
  skip_cert_check              = var.skip_cert_check
  custom_pull_secret           = var.custom_pull_secret
  trusted_cas                  = var.trusted_cas
  network_zone                 = var.network_zone
  enable_istio                 = var.enable_istio
  proxy_secret_name            = var.proxy_secret_name
  metadata_enrichment_enabled  = var.metadata_enrichment_enabled
  telemetry_ingest_protocols   = var.telemetry_ingest_protocols
  values_override              = var.values_override

  providers = {
    kubernetes = kubernetes
    helm       = helm
    kubectl    = kubectl
  }
}
