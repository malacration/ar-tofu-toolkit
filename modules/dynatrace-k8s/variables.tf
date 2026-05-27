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
  description = "Capacidades habilitadas no ActiveGate. Por padrao inclui routing e dynatrace-api. kubernetes-monitoring e adicionado automaticamente quando enable_kubernetes_monitoring = true."
  type        = list(string)
  default     = ["routing", "dynatrace-api"]
}

variable "activegate_resources" {
  description = "Resource requests e limits para os pods do ActiveGate."
  type = object({
    requests = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }), {})
    limits = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }), {})
  })
  default = null
}

variable "enable_kubernetes_monitoring" {
  description = "Se true, adiciona kubernetes-monitoring as capabilities do ActiveGate e habilita anotacoes de monitoramento automatico da API Kubernetes."
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
  description = "Se true, habilita metadata enrichment nos workloads monitorados."
  type        = bool
  default     = true
}

variable "telemetry_ingest_protocols" {
  description = "Protocolos opcionais para habilitar telemetry ingest no cluster."
  type        = list(string)
  default     = []
}

variable "oneagent" {
  description = "Configuracao do OneAgent deployado como DaemonSet nos nodes de workload."
  type = object({
    enabled     = optional(bool, true)
    mode        = optional(string, "cloudNativeFullStack")
    host_group  = optional(string, null)
    auto_update = optional(bool, true)

    # Deep monitoring: namespaces com a label abaixo recebem injecao de codigo.
    # Para injetar em todos os namespaces, defina inject_all_namespaces = true.
    # Adicione a label nos namespaces da aplicacao:
    #   kubectl label namespace <ns> dynatrace-monitoring=enabled
    inject_all_namespaces    = optional(bool, false)
    namespace_selector_label = optional(string, "dynatrace-monitoring")
    namespace_selector_value = optional(string, "enabled")

    node_selector = optional(map(string), {})

    tolerations = optional(list(object({
      key      = optional(string)
      operator = optional(string, "Exists")
      effect   = optional(string)
    })), [])

    resources = optional(object({
      requests = optional(object({
        cpu    = optional(string)
        memory = optional(string)
      }), null)
      limits = optional(object({
        cpu    = optional(string)
        memory = optional(string)
      }), null)
    }), null)

    args = optional(list(string), [])
    env  = optional(map(string), {})
  })
  default = {}
}

variable "values_override" {
  description = "Mapa adicional de values do Helm aplicado por ultimo."
  type        = any
  default     = {}
}
