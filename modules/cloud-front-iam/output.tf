output "iam_user_name" {
  description = "Nome do usuário IAM criado para o site"
  value       = aws_iam_user.site.name
}

output "iam_access_key_id" {
  description = "Access-Key ID"
  value       = aws_iam_access_key.site.id
  sensitive   = true
}

output "iam_secret_access_key" {
  description = "Secret-Access-Key (só aparece no primeiro apply!)"
  value       = aws_iam_access_key.site.secret
  sensitive   = true
}