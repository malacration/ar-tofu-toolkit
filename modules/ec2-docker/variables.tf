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
  description = "Lista de chaves públicas (ssh-ed25519/ssh-rsa...) para o usuário ec2-user"
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
  default     = 20
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

variable "attach_data_volume" {
  description = "Se true, anexa um volume de dados à instância"
  type        = bool
  default     = true
}

variable "data_volume_existing_id" {
  description = "ID de um EBS existente para anexar (opcional). Se null, o módulo cria um novo volume"
  type        = string
  default     = null
}

variable "data_volume_size_gb" {
  description = "Tamanho do EBS criado quando não é informado um existente"
  type        = number
  default     = 20
}

variable "data_volume_type" {
  description = "Tipo do EBS criado (gp3, gp2, io1, io2...)"
  type        = string
  default     = "gp3"
}

variable "data_volume_iops" {
  description = "IOPS para volumes que suportam (ex.: gp3/io1/io2). Ignorado se não aplicável"
  type        = number
  default     = 3000
}

variable "data_volume_throughput" {
  description = "Throughput (MB/s) para gp3. Ignorado se não aplicável"
  type        = number
  default     = 125
}

variable "data_volume_device_name" {
  description = "Device name lógico para anexar (Nitro traduz para NVMe). Ex.: /dev/sdf"
  type        = string
  default     = "/dev/sdf"
}

variable "data_volume_mount_path" {
  description = "Ponto de montagem para o volume de dados (se auto-format/mount)"
  type        = string
  default     = "/data"
}

variable "data_volume_fs" {
  description = "Filesystem usado ao formatar o volume"
  type        = string
  default     = "xfs"
}

variable "data_volume_auto_format_mount" {
  description = "Se true, formata e monta o volume via cloud-init"
  type        = bool
  default     = true
}