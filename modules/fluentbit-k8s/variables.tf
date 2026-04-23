variable "eks_cluster_name" {
  description = "Nome do cluster EKS usado para compor o campo service enviado ao Loki."
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes onde o Fluent Bit sera instalado."
  type        = string
  default     = "logging"
}

variable "create_namespace" {
  description = "Se true, o Helm cria o namespace caso ele nao exista."
  type        = bool
  default     = true
}

variable "helm_release_name" {
  description = "Nome do release Helm do Fluent Bit."
  type        = string
  default     = "fluent-bit"
}

variable "chart" {
  description = "Configuracao do chart Helm do Fluent Bit."
  type = object({
    repository = optional(string, "https://fluent.github.io/helm-charts")
    name       = optional(string, "fluent-bit")
    version    = optional(string, "0.57.0")
  })
  default = {}
}

variable "service_account_name" {
  description = "Nome do service account criado pelo chart do Fluent Bit."
  type        = string
  default     = "fluent-bit"
}

variable "config" {
  description = "Conteudo dos blocos config.service, config.inputs, config.filters, config.outputs e config.customParsers do chart."
  type = object({
    service        = string
    inputs         = string
    filters        = string
    outputs        = string
    custom_parsers = string
  })
}

variable "lua_scripts" {
  description = "Mapa de scripts Lua a montar em /fluent-bit/scripts. A chave e o nome do arquivo, e o valor e o conteudo."
  type        = map(string)
}

variable "excluded_node_names" {
  description = "Lista de nomes de nodes Kubernetes onde o DaemonSet nao deve ser agendado."
  type        = list(string)
  default     = []
}

variable "pod_labels" {
  description = "Labels adicionais aplicados aos pods do Fluent Bit, se suportado pelo chart."
  type        = map(string)
  default     = {}
}

variable "pod_annotations" {
  description = "Annotations adicionais aplicadas aos pods do Fluent Bit."
  type        = map(string)
  default     = {}
}

variable "values_override" {
  description = "Mapa adicional de values do Helm aplicado por ultimo, permitindo sobrescrever qualquer configuracao do chart."
  type        = any
  default     = {}
}
