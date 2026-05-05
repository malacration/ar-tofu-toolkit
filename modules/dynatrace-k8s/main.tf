
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
