output "artifact_hash" {
  description = "Hash calculado a partir dos arquivos locais do stack."
  value       = local.artifact_hash
}

output "remote_stack_dir" {
  description = "Diretorio remoto usado para armazenar os artefatos do stack."
  value       = local.remote_stack_dir
}

output "deploy_id" {
  description = "ID da execucao de deploy controlada pelo Terraform."
  value       = terraform_data.deploy.id
}

output "traefik_routes" {
  description = "Rotas do Traefik agrupadas por stack e por service neste stack."
  value       = local.traefik_routes_by_stack
}
