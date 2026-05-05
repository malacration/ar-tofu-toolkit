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
