locals {
  effective_region = coalesce(var.aws_region, data.aws_region.current.id)
  effective_cluster_name = var.cluster_name == null ? var.eks_cluster_name : (
    trimspace(var.cluster_name) != "" ? trimspace(var.cluster_name) : var.eks_cluster_name
  )

  effective_activegate_capabilities = distinct(concat(
    var.activegate_capabilities,
    var.enable_kubernetes_monitoring ? ["kubernetes-monitoring"] : []
  ))

  helm_values = {
    csidriver = {
      enabled = false
    }
  }

  dynakube_annotations = var.enable_kubernetes_monitoring ? {
    "feature.dynatrace.com/automatic-kubernetes-api-monitoring"              = "true"
    "feature.dynatrace.com/automatic-kubernetes-api-monitoring-cluster-name" = local.effective_cluster_name
  } : {}

  dynakube_spec = merge(
    {
      apiUrl = var.tenant_url
      tokens = var.dynakube_name
      activeGate = {
        capabilities = local.effective_activegate_capabilities
      }
    },
    var.custom_pull_secret != null ? { customPullSecret = var.custom_pull_secret } : {},
    var.trusted_cas != null ? { trustedCAs = var.trusted_cas } : {},
    var.skip_cert_check ? { skipCertCheck = true } : {},
    var.network_zone != null ? { networkZone = var.network_zone } : {},
    var.enable_istio ? { enableIstio = true } : {},
    var.proxy_secret_name != null ? { proxy = { valueFrom = var.proxy_secret_name } } : {},
    var.metadata_enrichment_enabled ? { metadataEnrichment = { enabled = true } } : {},
    length(var.telemetry_ingest_protocols) > 0 ? { telemetryIngest = { protocols = var.telemetry_ingest_protocols } } : {}
  )
}
