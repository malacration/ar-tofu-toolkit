variable "sub_domain" {
  description = "Subdomínio (ex.: 'windson'). Use vazio para registrar no apex do domínio."
  type        = string
}

variable "domain" {
  description = "Domínio base (ex.: 'artempestade.com.br')."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID onde a EC2 será criada."
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2."
  type        = string
  default = "t4g.micro"
}

variable "ssh_authorized_keys" {
  description = "Lista de chaves públicas para o usuário ubuntu"
  type        = list(string)
}