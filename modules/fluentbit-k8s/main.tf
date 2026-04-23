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
