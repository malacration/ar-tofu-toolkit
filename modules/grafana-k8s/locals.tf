locals {
  rendered_loki_datasources = [
    for datasource in var.loki_datasources : merge(
      {
        name      = datasource.name
        uid       = datasource.uid
        type      = "loki"
        access    = "proxy"
        url       = datasource.url
        isDefault = datasource.is_default
        editable  = datasource.editable
      },
      length(datasource.json_data) == 0 ? {} : { jsonData = datasource.json_data },
      length(datasource.secure_json_data) == 0 ? {} : { secureJsonData = datasource.secure_json_data }
    )
  ]

  persistence_values = {
    persistence = merge(
      tomap({
        enabled = var.persistence.enabled
      }),
      var.persistence.enabled ? tomap({
        size        = var.persistence.size
        accessModes = var.persistence.access_modes
      }) : tomap({}),
      var.persistence.enabled && var.persistence.storage_class != null ? tomap({
        storageClassName = var.persistence.storage_class
      }) : tomap({})
    )
  }

  loki_datasource_values = length(local.rendered_loki_datasources) == 0 ? {} : {
    datasources = {
      "datasources.yaml" = {
        apiVersion  = 1
        datasources = local.rendered_loki_datasources
      }
    }
  }

  generated_values = merge(
    {
      serviceAccount = {
        create = true
        name   = var.service_account_name
      }

      service = {
        type = var.service.type
        port = var.service.port
      }
    },
    local.persistence_values,
    local.loki_datasource_values,
  )
}
