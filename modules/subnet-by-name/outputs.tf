output "subnet_ids" {
  description = "Lista de subnet IDs cujo Name começa com o prefixo"
  value       = [for s in local.matched : s.id]
}

output "subnets_detailed" {
  description = "Lista detalhada de subnets que batem o prefixo (id, az, cidr, name)"
  value       = local.matched
}