terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Coleta subnets (todas) ou apenas na AZ informada
data "aws_subnets" "all" {
  count = var.zone == null ? 1 : 0
}

data "aws_subnets" "in_zone" {
  count = var.zone == null ? 0 : 1
  filter {
    name   = "availability-zone"
    values = [var.zone]
  }
}

# Lista de IDs candidata (dependendo se zone foi passado)
locals {
  candidate_ids = var.zone == null ? data.aws_subnets.all[0].ids : data.aws_subnets.in_zone[0].ids
}

# Abrimos cada subnet para ler tags/atributos e filtrar por prefixo do Name
data "aws_subnet" "selected" {
  for_each = toset(local.candidate_ids)
  id       = each.value
}

# Filtra por tag Name iniciando com name_prefix
locals {
  matched = [
    for s in data.aws_subnet.selected :
    {
      id  = s.id
      az  = s.availability_zone
      cidr = s.cidr_block
      name = try(s.tags.Name, "")
    }
    if startswith(try(s.tags.Name, ""), var.name_prefix)
  ]
}
