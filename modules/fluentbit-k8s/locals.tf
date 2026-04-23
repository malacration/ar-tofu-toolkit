locals {
  affinity_values = length(var.excluded_node_names) == 0 ? {} : {
    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [
            {
              matchExpressions = [
                {
                  key      = "kubernetes.io/hostname"
                  operator = "NotIn"
                  values   = var.excluded_node_names
                }
              ]
            }
          ]
        }
      }
    }
  }

  generated_values = merge(
    {
      kind = "DaemonSet"

      rbac = {
        create = true
      }

      serviceAccount = {
        create = true
        name   = var.service_account_name
      }

      podLabels      = var.pod_labels
      podAnnotations = var.pod_annotations

      luaScripts = var.lua_scripts

      config = {
        service       = trimspace(var.config.service)
        inputs        = trimspace(var.config.inputs)
        filters       = trimspace(var.config.filters)
        outputs       = trimspace(var.config.outputs)
        customParsers = trimspace(var.config.custom_parsers)
      }
    },
    local.affinity_values,
  )
}
