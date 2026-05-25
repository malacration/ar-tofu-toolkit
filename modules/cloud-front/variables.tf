variable "project-name" {
  description = "Nome do projeto"
  type        = string
}

variable "cliente_name" {
  description = "Nome do cliente a ser atendico"
  type        = string
}

variable "cliente_group" {
  description = "Nome do cliente a ser atendico"
  type        = string
}

variable "path_adicional" {
  description = "arquivos adicionais de um diretorio"
  type        = string
  default     = ""
}


variable "environment" {
  description = "Ambiente do projeto"
  type        = string
}

variable "release_version" {
  description = "Versao do release GitHub; use none para dist local e -1 para usar a branch principal"
  type        = string
  default     = "none"
}

variable "repo_owner" {
  description = "The owner of the GitHub repository"
  type        = string
  default     = "malacration"
}

variable "repo_name" {
  description = "The name of the GitHub repository"
  type        = string
  default     = "sap-front"
}

variable "github_token" {
  description = "Github token"
  type        = string
  default     = "none"
}

variable "zone_id" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
  default     = ""
}

variable "full_dns_name" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
  default     = ""
}

variable "create_cloudfront" {
  description = "Se false, nao cria a distribuicao CloudFront nem a regra Route53. O bucket S3 e os arquivos sao criados normalmente."
  type        = bool
  default     = true
}
