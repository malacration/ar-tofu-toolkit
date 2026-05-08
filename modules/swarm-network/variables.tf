variable "connection" {
  description = "Objeto de conexao SSH e alvo do manager. Quando informado, prioriza esses valores em vez das variaveis soltas equivalentes."
  type = object({
    manager_host                 = optional(string)
    ssh_user                     = optional(string)
    ssh_port                     = optional(number)
    ssh_private_key_path         = optional(string)
    ssh_timeout                  = optional(string)
    ssh_strict_host_key_checking = optional(bool)
  })
  default  = {}
  nullable = false
}

variable "manager_host" {
  description = "IP ou hostname do manager do Swarm."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_user" {
  description = "Usuario SSH do host remoto."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_port" {
  description = "Porta SSH do host remoto."
  type        = number
  default     = null
  nullable    = true
}

variable "ssh_private_key_path" {
  description = "Caminho da chave privada SSH usada pelo cliente local."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_timeout" {
  description = "Timeout da conexao SSH."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_strict_host_key_checking" {
  description = "Quando true, exige verificacao normal de host key pelo SSH local."
  type        = bool
  default     = null
  nullable    = true
}

variable "network_name" {
  description = "Nome da rede overlay compartilhada no Swarm."
  type        = string
}

variable "driver" {
  description = "Driver da rede Docker."
  type        = string
  default     = "overlay"
}

variable "attachable" {
  description = "Quando true, cria a rede como attachable."
  type        = bool
  default     = true
}

variable "remove_on_destroy" {
  description = "Quando true, remove a rede no destroy do Terraform/OpenTofu."
  type        = bool
  default     = false
}
