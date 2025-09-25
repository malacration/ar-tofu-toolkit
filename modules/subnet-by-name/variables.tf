variable "name_prefix" {
  description = "Prefixo do tag Name das subnets (match por 'starts with')"
  type        = string
}

variable "zone" {
  description = "Availability Zone opcional (ex.: us-east-1a). Se null, busca em todas as AZs"
  type        = string
  default     = null
}