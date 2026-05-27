locals {
  effective_region = coalesce(var.aws_region, data.aws_region.current.id)
  effective_cluster_name = var.cluster_name == null ? var.eks_cluster_name : (
    trimspace(var.cluster_name) != "" ? trimspace(var.cluster_name) : var.eks_cluster_name
  )

  effective_activegate_capabilities = distinct(concat(
    var.activegate_capabilities,
    var.enable_kubernetes_monitoring ? ["kubernetes-monitoring"] : []
  ))

  # CSI driver e obrigatorio para cloudNativeFullStack (injecao de codigo)
  csi_driver_enabled = var.oneagent.enabled && var.oneagent.mode == "cloudNativeFullStack"

  helm_values = {
    csidriver = {
      enabled = local.csi_driver_enabled
    }
  }

  dynakube_annotations = var.enable_kubernetes_monitoring ? {
    "feature.dynatrace.com/automatic-kubernetes-api-monitoring"              = "true"
    "feature.dynatrace.com/automatic-kubernetes-api-monitoring-cluster-name" = local.effective_cluster_name
  } : {}

  # namespaceSelector controla quais namespaces recebem injecao de codigo (deep monitoring)
  # Aplica-se apenas ao modo cloudNativeFullStack
  namespace_selector = (
    !var.oneagent.inject_all_namespaces && var.oneagent.mode == "cloudNativeFullStack"
  ) ? {
    namespaceSelector = {
      matchLabels = {
        (var.oneagent.namespace_selector_label) = var.oneagent.namespace_selector_value
      }
    }
  } : {}

  oneagent_env = [
    for k, v in var.oneagent.env : { name = k, value = v }
  ]

  oneagent_resources = var.oneagent.resources != null ? {
    oneAgentResources = merge(
      var.oneagent.resources.requests != null ? {
        requests = { for k, v in var.oneagent.resources.requests : k => v if v != null }
      } : {},
      var.oneagent.resources.limits != null ? {
        limits = { for k, v in var.oneagent.resources.limits : k => v if v != null }
      } : {},
    )
  } : {}

  oneagent_spec = merge(
    local.namespace_selector,
    length(var.oneagent.node_selector) > 0 ? { nodeSelector = var.oneagent.node_selector } : {},
    length(var.oneagent.tolerations) > 0 ? { tolerations = var.oneagent.tolerations } : {},
    var.oneagent.host_group != null ? { hostGroup = var.oneagent.host_group } : {},
    !var.oneagent.auto_update ? { autoUpdate = false } : {},
    local.oneagent_resources,
    length(var.oneagent.args) > 0 ? { args = var.oneagent.args } : {},
    length(local.oneagent_env) > 0 ? { env = local.oneagent_env } : {},
  )

  activegate_resources = var.activegate_resources != null ? {
    resources = merge(
      try(length(var.activegate_resources.requests) > 0, false) ? {
        requests = { for k, v in var.activegate_resources.requests : k => v if v != null }
      } : {},
      try(length(var.activegate_resources.limits) > 0, false) ? {
        limits = { for k, v in var.activegate_resources.limits : k => v if v != null }
      } : {},
    )
  } : {}

  dynakube_spec = merge(
    {
      apiUrl = var.tenant_url
      tokens = var.dynakube_name
      activeGate = merge(
        { capabilities = local.effective_activegate_capabilities },
        local.activegate_resources,
      )
      metadataEnrichment = {
        enabled = var.metadata_enrichment_enabled
      }
    },
    var.oneagent.enabled ? {
      oneAgent = {
        (var.oneagent.mode) = local.oneagent_spec
      }
    } : {},
    var.custom_pull_secret != null ? { customPullSecret = var.custom_pull_secret } : {},
    var.trusted_cas != null ? { trustedCAs = var.trusted_cas } : {},
    var.skip_cert_check ? { skipCertCheck = true } : {},
    var.network_zone != null ? { networkZone = var.network_zone } : {},
    var.enable_istio ? { enableIstio = true } : {},
    var.proxy_secret_name != null ? { proxy = { valueFrom = var.proxy_secret_name } } : {},
    length(var.telemetry_ingest_protocols) > 0 ? { telemetryIngest = { protocols = var.telemetry_ingest_protocols } } : {}
  )
}
