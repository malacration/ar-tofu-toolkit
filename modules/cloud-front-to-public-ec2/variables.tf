variable "zone_id" {
    description = "id da zona de disponibilidade"
    type        = string
}

variable "domain" {
    description = "dominio para publicação do cloud-front"
    type        = string
}

variable "instance_id_ec2"{
    description = "instancia id. Ec2"
    type        = string
}

variable "origin_protocol_policy"{
    description = "Origin protocol policy to apply to your origin. One of http-only, https-only, or match-viewer."
    type        = string
}