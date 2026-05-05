variable "cluster_name" {
  description = "Nome do cluster exibido no Dynatrace."
  type        = string

  validation {
    condition     = trimspace(var.cluster_name) != ""
    error_message = "cluster_name nao pode ser vazio."
  }
}

variable "tenant_url" {
  description = "URL do tenant Dynatrace, incluindo o sufixo /api."
  type        = string

  validation {
    condition     = can(regex("/api/?$", var.tenant_url))
    error_message = "tenant_url deve terminar com /api."
  }
}

variable "namespace" {
  description = "Namespace Kubernetes onde o Dynatrace Operator sera instalado."
  type        = string
  default     = "dynatrace"
}

variable "create_namespace" {
  description = "Se true, cria o namespace do Dynatrace."
  type        = bool
  default     = true
}

variable "helm_release_name" {
  description = "Nome do release Helm do Dynatrace Operator."
  type        = string
  default     = "dynatrace-operator"
}

variable "dynakube_name" {
  description = "Nome do recurso DynaKube e do secret de tokens criado pelo modulo."
  type        = string
  default     = "dynakube"
}

variable "chart" {
  description = "Configuracao do chart Helm do Dynatrace Operator."
  type = object({
    repository = optional(string, "oci://public.ecr.aws/dynatrace")
    name       = optional(string, "dynatrace-operator")
    version    = optional(string)
  })
  default = {}
}

variable "tokens" {
  description = "Tokens usados pelo Dynatrace Operator."
  type = object({
    api_token         = string
    data_ingest_token = string
  })
  sensitive = true
}

variable "activegate_capabilities" {
  description = "Lista de capacidades do ActiveGate no DynaKube."
  type        = list(string)
  default     = []
}

variable "enable_kubernetes_monitoring" {
  description = "Se true, habilita o monitoramento da API Kubernetes no Dynatrace."
  type        = bool
  default     = true
}

variable "skip_cert_check" {
  description = "Se true, desabilita a validacao do certificado entre o Operator e o tenant Dynatrace."
  type        = bool
  default     = false
}

variable "custom_pull_secret" {
  description = "Nome de um secret existente para pull de imagens privadas."
  type        = string
  default     = null
}

variable "trusted_cas" {
  description = "Nome de um ConfigMap existente com CAs customizadas."
  type        = string
  default     = null
}

variable "network_zone" {
  description = "Network zone opcional para OneAgent e ActiveGate."
  type        = string
  default     = null
}

variable "enable_istio" {
  description = "Se true, habilita integracao com Istio no DynaKube."
  type        = bool
  default     = false
}

variable "proxy_secret_name" {
  description = "Nome de um secret existente com a chave proxy para configurar proxy."
  type        = string
  default     = null
}

variable "metadata_enrichment_enabled" {
  description = "Se true, habilita metadata enrichment no DynaKube."
  type        = bool
  default     = false
}

variable "telemetry_ingest_protocols" {
  description = "Protocolos opcionais para habilitar telemetry ingest no cluster."
  type        = list(string)
  default     = []
}

variable "values_override" {
  description = "Mapa adicional de values do Helm aplicado por ultimo."
  type        = any
  default     = {}
}
