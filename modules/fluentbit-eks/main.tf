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

resource "helm_release" "fluentbit" {
  name             = var.helm_release_name
  repository       = var.chart.repository
  chart            = var.chart.name
  version          = var.chart.version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = [
    yamlencode(local.generated_values),
    yamlencode(var.values_override),
  ]
}
