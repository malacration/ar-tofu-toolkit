variable "instance_id" {
  type        = string
  description = "ID da instância EC2 alvo (ex.: i-0123456789abcdef0)"
}

variable "local_path" {
  type        = string
  description = "Diretório local com docker-compose.yml e outros arquivos"
}

variable "remote_dir" {
  type        = string
  default     = "/srv/app"
  description = "Diretório de destino na instância"
}

variable "compose_file" {
  type        = string
  default     = "docker-compose.yml"
  description = "Nome do arquivo docker-compose dentro de remote_dir"
}

variable "ssh_user" {
  type        = string
  default     = "ubuntu"
  description = "Usuário SSH da instância"
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "Conteúdo da chave privada SSH (ex.: file(\"~/.ssh/id_rsa\"))"
}

variable "use_public_ip" {
  type        = bool
  default     = true
  description = "Usar IP público (true) ou privado (false) para SSH"
}

variable "run_pull" {
  type        = bool
  default     = true
  description = "Executa 'docker compose pull' antes do up"
}

variable "prune_images" {
  type        = bool
  default     = true
  description = "Executa 'docker image prune -f' após o deploy"
}

# Opcional: para forçar redeploy manual sem mudar arquivos
variable "force_redeploy_nonce" {
  type        = string
  default     = ""
  description = "Troque o valor para forçar reexecução do deploy"
}

# Se precisar de bastion, descomente no connection acima e defina:
# variable "bastion_host"        { type = string, default = null }
# variable "bastion_user"        { type = string, default = "ubuntu" }
# variable "bastion_private_key" { type = string, default = null, sensitive = true }
