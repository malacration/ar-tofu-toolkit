variable "domain_name" {
  description = "Nome do dominio OpenSearch na AWS."
  type        = string
}

variable "engine_version" {
  description = "Versao do engine OpenSearch (ex: OpenSearch_2.13, Elasticsearch_7.10)."
  type        = string
  default     = "OpenSearch_2.13"
}

variable "instance" {
  description = "Configuracao das instancias do cluster OpenSearch."
  type = object({
    type               = optional(string, "t3.small.search")
    count              = optional(number, 1)
    dedicated_master   = optional(bool, false)
    master_type        = optional(string, "t3.small.search")
    master_count       = optional(number, 3)
    zone_awareness     = optional(bool, false)
    availability_zones = optional(number, 1)
  })
  default = {}
}

variable "storage" {
  description = "Configuracao de armazenamento EBS por no."
  type = object({
    volume_type = optional(string, "gp3")
    volume_size = optional(number, 20)
    iops        = optional(number, null)
    throughput  = optional(number, null)
  })
  default = {}
}

variable "network" {
  description = "Configuracao de rede. Se subnet_ids for preenchido, o dominio sera criado dentro de uma VPC."
  type = object({
    vpc_id                    = optional(string, null)
    subnet_ids                = optional(list(string), [])
    additional_security_group_ids = optional(list(string), [])
    allowed_cidr_blocks       = optional(list(string), [])
  })
  default = {}
}

variable "master_user" {
  description = "Credenciais do usuario master para fine-grained access control (FGAC)."
  type = object({
    username = string
    password = string
  })
  sensitive = true
}

variable "log_index" {
  description = "Prefixo do indice de logs enviados pelo FluentBit ao OpenSearch."
  type        = string
  default     = "logs"
}

variable "log_index_date_format" {
  description = "Formato de data para sufixo do indice no Logstash format (ex: %Y.%m.%d)."
  type        = string
  default     = "%Y.%m.%d"
}

variable "tags" {
  description = "Tags aplicadas ao dominio OpenSearch e recursos relacionados."
  type        = map(string)
  default     = {}
}
