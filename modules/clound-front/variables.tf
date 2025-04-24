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
  description = "The version of the GitHub release to download"
  type        = string
  default = "none"
}

variable "repo_owner" {
  description = "The owner of the GitHub repository"
  type        = string
  default = "malacration"
}

variable "repo_name" {
  description = "The name of the GitHub repository"
  type        = string
  default = "sap-front"
}

variable "github_token" {
  description = "Github token"
  type        = string
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