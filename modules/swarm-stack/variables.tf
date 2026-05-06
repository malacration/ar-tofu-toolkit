variable "stack_name" {
  description = "Nome do stack no Docker Swarm."
  type        = string
}

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

variable "artifact_path" {
  description = "Diretorio local com os artefatos do stack que devem ser enviados ao manager."
  type        = string

  validation {
    condition     = can(fileset(var.artifact_path, "**"))
    error_message = "artifact_path precisa apontar para um diretorio existente."
  }
}

variable "compose_file" {
  description = "Arquivo Compose relativo ao artifact_path."
  type        = string
  default     = "docker-compose.yml"
}

variable "env_file" {
  description = "Arquivo .env shell-compatible relativo ao artifact_path para carregar antes do deploy."
  type        = string
  default     = null
}

variable "manager_host" {
  description = "IP ou hostname do manager do Swarm que recebera o deploy."
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
  description = "Caminho da chave privada SSH usada pelo cliente local. Se null, usa o ssh-agent ou a configuracao padrao do SSH."
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

variable "remote_base_dir" {
  description = "Diretorio base no manager onde os artefatos serao extraidos."
  type        = string
  default     = "/opt/swarm/stacks"
}

variable "prune" {
  description = "Executa docker stack deploy com --prune."
  type        = bool
  default     = true
}

variable "with_registry_auth" {
  description = "Executa docker stack deploy com --with-registry-auth."
  type        = bool
  default     = false
}

variable "additional_deploy_args" {
  description = "Argumentos extras enviados ao docker stack deploy."
  type        = list(string)
  default     = []
}

variable "deployment_triggers" {
  description = "Mapa de valores que devem forcar novo deploy quando a infraestrutura relacionada mudar."
  type        = map(string)
  default     = {}
}

variable "remove_remote_artifacts_on_destroy" {
  description = "Quando true, remove o diretorio remoto da stack apos a remocao do Swarm."
  type        = bool
  default     = true
}

variable "traefik_routes" {
  description = "Metadados opcionais das rotas publicadas pelo Traefik para este stack."
  type = list(object({
    service = string
    hosts   = list(string)
  }))
  default = []
}
