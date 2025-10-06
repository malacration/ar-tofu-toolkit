variable "name" {
  description = "Prefixo/Name tag da instância"
  type        = string
  default     = "docker-ec2"
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "associate_public_ip" {
  description = "Se true, atribui IP público"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Tipo da instância (padrão econômico ARM/Graviton)"
  type        = string
  default     = "t4g.micro"
}

variable "ami_arch" {
  description = "Override da arquitetura da AMI: arm64 ou x86_64 (null = derivar do instance_type)"
  type        = string
  default     = null
  validation {
    condition     = var.ami_arch == null || contains(["arm64", "x86_64"], var.ami_arch)
    error_message = "ami_arch deve ser null, 'arm64' ou 'x86_64'."
  }
}

variable "ssh_authorized_keys" {
  description = "Lista de chaves públicas (ssh-ed25519/ssh-rsa...) para o usuário ubuntu"
  type        = list(string)
  default     = []
}

variable "user_data_extra" {
  description = "Comandos shell adicionais a executar após instalar o Docker (opcional)"
  type        = string
  default     = ""
}

variable "root_volume_size_gb" {
  description = "Tamanho do volume raiz (GB)"
  type        = number
  default     = 15
}

variable "ssh_ingress_cidrs" {
  description = "CIDRs para liberar SSH (porta 22). Vazio = sem SSH aberto"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Nome do Key Pair da AWS (opcional; útil para acesso inicial)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}


//Volume

variable "create_data_volume" {
  type    = bool
  default = false
}


variable "data_volume_existing_id" {
  description = "ID de um EBS existente para anexar (mesma AZ da instância). Se null, nada será anexado"
  type        = string
  default     = null
}

variable "data_volume_device_name" {
  description = "Device name lógico ao anexar (Nitro traduz p/ NVMe). Ex.: /dev/sdf"
  type        = string
  default     = "/dev/sdf"
}

variable "data_volume_mount_path" {
  description = "Ponto de montagem para o volume de dados (se habilitar montagem)"
  type        = string
  default     = "/data"
}

variable "data_volume_fs" {
  description = "Filesystem para formatar (apenas se auto_format=true)"
  type        = string
  default     = "xfs"
}

variable "data_volume_auto_format_mount" {
  description = "Se true, formata (POTENCIALMENTE APAGA DADOS) e monta via cloud-init."
  type    = bool
  default = false
}

variable "data_volume_owner_user"  { 
  type = string
  default = "ubuntu" 
}
variable "data_volume_owner_group" { 
  type = string
  default = "data" 
}
variable "data_volume_dir_mode"    { 
  type = string
  default = "2775" 
}
