variable "namespace" {
  description = "Namespace Kubernetes onde o Grafana sera instalado."
  type        = string
  default     = "monitoring"
}

variable "create_namespace" {
  description = "Se true, o Helm cria o namespace caso ele nao exista."
  type        = bool
  default     = true
}

variable "helm_release_name" {
  description = "Nome do release Helm do Grafana."
  type        = string
  default     = "grafana"
}

variable "chart" {
  description = "Configuracao do chart Helm do Grafana."
  type = object({
    repository = optional(string, "https://grafana.github.io/helm-charts")
    name       = optional(string, "grafana")
    version    = optional(string, "10.3.0")
  })
  default = {}
}

variable "service_account_name" {
  description = "Nome do service account criado pelo chart do Grafana."
  type        = string
  default     = "grafana"
}

variable "service" {
  description = "Configuracao do service Kubernetes exposto pelo chart."
  type = object({
    type = optional(string, "ClusterIP")
    port = optional(number, 80)
  })
  default = {}
}

variable "persistence" {
  description = "Configuracao de persistencia do Grafana."
  type = object({
    enabled       = optional(bool, false)
    size          = optional(string, "10Gi")
    storage_class = optional(string)
    access_modes  = optional(list(string), ["ReadWriteOnce"])
  })
  default = {}
}

variable "loki_datasources" {
  description = "Lista de datasources Loki a serem provisionados no Grafana. Pode ser vazia."
  type = list(object({
    name             = optional(string, "Loki")
    uid              = optional(string, "loki")
    url              = string
    is_default       = optional(bool, true)
    editable         = optional(bool, true)
    json_data        = optional(map(any), {})
    secure_json_data = optional(map(string), {})
  }))
  default = []
}

variable "opensearch_datasources" {
  description = "Lista de datasources OpenSearch a serem provisionados no Grafana. Requer o plugin grafana-opensearch-datasource instalado automaticamente quando a lista nao for vazia."
  type = list(object({
    name            = optional(string, "OpenSearch")
    uid             = optional(string, "opensearch")
    url             = string
    index           = optional(string, "logs-*")
    time_field      = optional(string, "@timestamp")
    engine_version  = optional(string, "2.13.0")
    basic_auth_user = optional(string, null)
    is_default      = optional(bool, false)
    editable        = optional(bool, true)
    json_data       = optional(map(any), {})
    secure_json_data = optional(map(string), {})
  }))
  default   = []
  sensitive = true
}

variable "extra_plugins" {
  description = "Plugins adicionais a instalar no Grafana (ex: ['grafana-piechart-panel'])."
  type        = list(string)
  default     = []
}

variable "sso" {
  description = "Configuracao de SSO via Keycloak (OAuth/OIDC). Deixe nulo para desabilitar."
  type = object({
    url                 = optional(string, null)
    realm               = optional(string, null)
    client_id           = optional(string, null)
    allow_sign_up       = optional(bool, true)
    role_attribute_path = optional(string, "contains(roles[*], 'admin') && 'Admin' || contains(roles[*], 'editor') && 'Editor' || 'Viewer'")
  })
  default = {}
}

variable "sso_client_secret" {
  description = "Client secret do Keycloak para o SSO. Separado do bloco sso para permitir outputs nao sensiveis."
  type        = string
  default     = null
  sensitive   = true
}

variable "values_override" {
  description = "Mapa adicional de values do Helm aplicado por ultimo, permitindo sobrescrever qualquer configuracao do chart."
  type        = any
  default     = {}
}

variable "resolve_service_url" {
  description = "Parametro mantido por compatibilidade, sem efeito. Este modulo nao faz descoberta automatica da URL do Grafana."
  type        = bool
  default     = false
}

variable "alb_rule" {
  description = "Adiciona uma listener rule em um ALB existente apontando para o Grafana."
  type = object({
    enabled      = optional(bool, false)
    alb_name     = optional(string, null)
    path         = optional(string, "/grafana")
    priority     = optional(number, 100)
    node_port    = optional(number, 30080)
    cluster_name = optional(string, null)
  })
  default = {}
}

variable "ingress" {
  description = "Configuracao do Ingress para expor o Grafana externamente via AWS ALB."
  type = object({
    enabled      = optional(bool, false)
    scheme       = optional(string, "internal")
    target_type  = optional(string, "instance")
    listen_ports = optional(string, "[{\"HTTP\": 80}]")
    path         = optional(string, "/")
    host         = optional(string, null)
    group_name   = optional(string, null)
    annotations  = optional(map(string), {})
  })
  default = {}
}
