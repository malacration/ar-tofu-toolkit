variable "eks_cluster_name" {
  description = "Nome do cluster EKS, usado para validar a existencia do cluster na conta/regiao do provider AWS."
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes onde o Loki sera instalado."
  type        = string
  default     = "loki"
}

variable "create_namespace" {
  description = "Se true, o Helm cria o namespace caso ele nao exista."
  type        = bool
  default     = true
}

variable "helm_release_name" {
  description = "Nome do release Helm do Loki."
  type        = string
  default     = "loki"
}

variable "chart" {
  description = "Configuracao do chart Helm do Loki."
  type = object({
    repository = optional(string, "https://grafana.github.io/helm-charts")
    name       = optional(string, "loki")
    version    = optional(string, "6.27.0")
  })
  default = {}
}

variable "aws_region" {
  description = "Regiao AWS do S3 usada pelo Loki. Se nulo, usa a regiao configurada no provider AWS."
  type        = string
  default     = null
}

variable "service_account_name" {
  description = "Nome do service account criado pelo chart do Loki."
  type        = string
  default     = "loki"
}

variable "tags" {
  description = "Tags comuns aplicadas aos recursos AWS criados pelo modulo."
  type        = map(string)
  default     = {}
}

variable "storage" {
  description = "Configuracao dos buckets S3 usados pelo Loki."
  type = object({
    create_bucket     = optional(bool, false)
    bucket_name       = string
    ruler_bucket_name = optional(string)
    force_destroy     = optional(bool, false)
    tags              = optional(map(string), {})
  })
}

variable "s3_auth" {
  description = "Modo de autenticacao S3 sem IRSA. Se create_credentials for true, o modulo cria user/policy/access key. Caso contrario, usa credenciais informadas."
  type = object({
    create_credentials = optional(bool, false)
    existing = optional(object({
      access_key_id     = string
      secret_access_key = string
    }))
    created = optional(object({
      iam_user_name   = optional(string, "loki-s3")
      iam_policy_name = optional(string, "loki-s3")
    }), {})
  })
  sensitive = true
}

variable "loki" {
  description = "Configuracoes principais do Loki expostas pelo modulo."
  type = object({
    deployment_mode      = optional(string, "Distributed")
    retention_period     = optional(string, "672h")
    schema_from          = optional(string, "2024-04-01")
    image_tag            = optional(string, "3.7.1")
    gateway_service_type = optional(string, "ClusterIP")
    force_path_style     = optional(bool, false)
  })
  default = {}
}

variable "replicas" {
  description = "Replica counts dos componentes principais do Loki em modo distributed."
  type = object({
    ingester        = optional(number, 3)
    distributor     = optional(number, 3)
    querier         = optional(number, 3)
    query_frontend  = optional(number, 2)
    query_scheduler = optional(number, 2)
    compactor       = optional(number, 1)
    index_gateway   = optional(number, 2)
    ruler           = optional(number, 1)
  })
  default = {}
}

variable "values_override" {
  description = "Mapa adicional de values do Helm aplicado por ultimo, permitindo sobrescrever qualquer configuracao do chart."
  type        = any
  default     = {}
}
