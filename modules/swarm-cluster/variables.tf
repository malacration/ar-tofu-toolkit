variable "connection_defaults" {
  description = "Defaults de conexao SSH aplicados aos hosts do cluster quando um host nao sobrescreve ssh_user/ssh_port. Tambem controla chave, timeout e host key checking do cliente local."
  type = object({
    ssh_user                     = optional(string)
    ssh_port                     = optional(number)
    ssh_private_key_path         = optional(string)
    ssh_timeout                  = optional(string)
    ssh_strict_host_key_checking = optional(bool)
  })
  default  = {}
  nullable = false
}

variable "manager_hosts" {
  description = "Lista ordenada de managers do cluster. O primeiro host e o bootstrap manager."
  type = list(object({
    host           = string
    ssh_user       = optional(string)
    ssh_port       = optional(number)
    advertise_addr = optional(string)
    listen_addr    = optional(string)
    node_name      = optional(string)
  }))
}

variable "worker_hosts" {
  description = "Lista de workers que devem participar do cluster."
  type = list(object({
    host           = string
    ssh_user       = optional(string)
    ssh_port       = optional(number)
    advertise_addr = optional(string)
    node_name      = optional(string)
  }))
  default = []
}

variable "ssh_private_key_path" {
  description = "Caminho da chave privada usada pelo cliente SSH local."
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_timeout" {
  description = "Timeout da conexao SSH usada pelo cliente local."
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

variable "swarm_port" {
  description = "Porta TCP do manager para join do Swarm."
  type        = number
  default     = 2377
}
