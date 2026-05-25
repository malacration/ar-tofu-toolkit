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

  rendered_opensearch_datasources = [
    for datasource in var.opensearch_datasources : merge(
      {
        name      = datasource.name
        uid       = datasource.uid
        type      = "grafana-opensearch-datasource"
        access    = "proxy"
        url       = datasource.url
        isDefault = datasource.is_default
        editable  = datasource.editable
      },
      datasource.basic_auth_user != null ? {
        basicAuth     = true
        basicAuthUser = datasource.basic_auth_user
      } : {},
      {
        jsonData = merge(
          {
            database       = datasource.index
            timeField      = datasource.time_field
            version        = datasource.engine_version
            flavor         = "opensearch"
            logMessageField = "log"
            logLevelField  = "level"
          },
          datasource.json_data
        )
      },
      length(datasource.secure_json_data) == 0 ? {} : { secureJsonData = datasource.secure_json_data }
    )
  ]

  all_datasources = concat(local.rendered_loki_datasources, local.rendered_opensearch_datasources)

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

  datasource_values = length(local.all_datasources) == 0 ? {} : {
    datasources = {
      "datasources.yaml" = {
        apiVersion  = 1
        datasources = local.all_datasources
      }
    }
  }

  opensearch_plugin = length(var.opensearch_datasources) > 0 ? ["grafana-opensearch-datasource"] : []
  plugins_list      = concat(local.opensearch_plugin, var.extra_plugins)
  plugins_values    = length(local.plugins_list) == 0 ? {} : { plugins = local.plugins_list }

  use_alb_rule = var.alb_rule.enabled && var.alb_rule.alb_name != null

  subpath = local.use_alb_rule ? trimprefix(var.alb_rule.path, "/") : (
    var.ingress.enabled && var.ingress.path != "/" ? trimprefix(var.ingress.path, "/") : null
  )

  server_ini = local.subpath != null ? {
    server = {
      root_url            = "%(protocol)s://%(domain)s/${local.subpath}"
      serve_from_sub_path = true
    }
  } : {}

  sso_enabled = (
    try(var.sso.url, null) != null &&
    try(var.sso.realm, null) != null &&
    try(var.sso.client_id, null) != null &&
    var.sso_client_secret != null
  )

  keycloak_base_url = local.sso_enabled ? "${var.sso.url}/realms/${var.sso.realm}/protocol/openid-connect" : null

  sso_ini = local.sso_enabled ? {
    "auth.generic_oauth" = {
      enabled             = true
      name                = "Keycloak"
      allow_sign_up       = var.sso.allow_sign_up
      client_id           = var.sso.client_id
      client_secret       = var.sso_client_secret
      scopes              = "openid email profile offline_access roles"
      auth_url            = "${local.keycloak_base_url}/auth"
      token_url           = "${local.keycloak_base_url}/token"
      api_url             = "${local.keycloak_base_url}/userinfo"
      role_attribute_path = var.sso.role_attribute_path
      role_attribute_strict = false
      use_pkce            = true
    }
  } : {}

  grafana_ini_merged = merge(local.server_ini, local.sso_ini)

  grafana_ini_values = length(local.grafana_ini_merged) == 0 ? {} : {
    "grafana.ini" = local.grafana_ini_merged
  }

  sso_keycloak_instructions = local.sso_enabled ? join("\n", [
    "",
    "============================================================",
    " Configuracao do Keycloak para SSO no Grafana",
    "============================================================",
    "",
    "Realm : ${var.sso.realm}",
    "Client: ${var.sso.client_id}",
    "URL   : ${var.sso.url}",
    "",
    "--- 1. Criar o Client no Keycloak ---",
    "- Acesse: ${var.sso.url}/admin/${var.sso.realm}/console",
    "- Va em Clients > Create client",
    "- Client ID             : ${var.sso.client_id}",
    "- Client type           : OpenID Connect",
    "- Client authentication : ON  (para ter client secret)",
    "- Valid redirect URIs   : <URL_DO_GRAFANA>/login/generic_oauth",
    "",
    "--- 2. Configurar o Mapper de Roles ---",
    "- Va em Client Scopes > roles > Mappers > Create mapper",
    "- Mapper type      : User Realm Role",
    "- Name             : realm-roles",
    "- Token Claim Name : roles",
    "- Add to ID token     : ON",
    "- Add to access token : ON",
    "- Add to userinfo     : ON",
    "",
    "--- 3. Criar os Roles no Realm ---",
    "- Va em Realm roles > Create role",
    "- Crie os roles: admin, editor  (viewer e o fallback)",
    "",
    "--- 4. Atribuir Roles aos Usuarios ---",
    "- Va em Users > [usuario] > Role mapping",
    "- Atribua os roles criados acima",
    "",
    "--- Mapeamento configurado ---",
    "roles[*] = 'admin'  --> Grafana Admin",
    "roles[*] = 'editor' --> Grafana Editor",
    "(qualquer outro)    --> Grafana Viewer",
    "",
    "Expressao: ${var.sso.role_attribute_path}",
    "",
    "============================================================",
  ]) : null

  service_type      = local.use_alb_rule ? "NodePort" : var.service.type
  service_node_port = local.use_alb_rule ? var.alb_rule.node_port : null

  generated_values = merge(
    {
      serviceAccount = {
        create = true
        name   = var.service_account_name
      }

      service = merge(
        {
          type = local.service_type
          port = var.service.port
        },
        local.service_node_port != null ? { nodePort = local.service_node_port } : {}
      )
    },
    local.persistence_values,
    local.datasource_values,
    local.plugins_values,
    local.grafana_ini_values,
  )
}
