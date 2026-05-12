
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

resource "kubernetes_namespace_v1" "dynatrace" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "dynatrace_operator" {
  name             = var.helm_release_name
  repository       = var.chart.repository
  chart            = var.chart.name
  version          = var.chart.version
  namespace        = var.namespace
  create_namespace = false

  values = [
    yamlencode(local.helm_values),
    yamlencode(var.values_override),
  ]

  depends_on = [kubernetes_namespace_v1.dynatrace]
}

resource "kubernetes_secret_v1" "tokens" {
  metadata {
    name      = var.dynakube_name
    namespace = var.namespace
  }

  data = {
    apiToken        = var.tokens.api_token
    dataIngestToken = var.tokens.data_ingest_token
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.dynatrace]
}

resource "kubectl_manifest" "dynakube" {
  yaml_body = yamlencode({
    apiVersion = "dynatrace.com/v1beta6"
    kind       = "DynaKube"
    metadata = {
      name        = var.dynakube_name
      namespace   = var.namespace
      annotations = local.dynakube_annotations
    }
    spec = local.dynakube_spec
  })

  depends_on = [
    helm_release.dynatrace_operator,
    kubernetes_secret_v1.tokens,
  ]
}
