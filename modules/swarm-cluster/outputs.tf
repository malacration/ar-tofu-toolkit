output "primary_manager_host" {
  description = "Host do manager principal usado para bootstrap do cluster."
  value       = local.primary_manager.host
}

output "primary_manager_connection" {
  description = "Objeto de conexao base do manager principal para uso em outros modulos."
  value = {
    manager_host = local.primary_manager.host
    ssh_user     = local.primary_manager.ssh_user
    ssh_port     = local.primary_manager.ssh_port
  }
}

output "primary_manager_ssh_user" {
  description = "Usuario SSH do manager principal."
  value       = local.primary_manager.ssh_user
}

output "primary_manager_ssh_port" {
  description = "Porta SSH do manager principal."
  value       = local.primary_manager.ssh_port
}

output "primary_manager_endpoint" {
  description = "Endereco anunciado pelo manager principal para join dos nos."
  value       = local.primary_manager_endpoint
}

output "manager_hosts" {
  description = "Lista normalizada de managers."
  value       = local.normalized_manager_hosts
}

output "worker_hosts" {
  description = "Lista normalizada de workers."
  value       = local.normalized_worker_hosts
}

output "cluster_members_hash" {
  description = "Hash da composicao atual do cluster."
  value       = local.cluster_members_hash
}
