data "aws_iam_account_alias" "this" {}

# Consulta à identidade atual (inclui account_id, arn e user_id)
data "aws_caller_identity" "current" {}

output "iam_info" {
  description = "Bloco completo com informações do usuário IAM e da conta"
  value = {
    account_id    = data.aws_caller_identity.current.account_id
    account_alias = try(data.aws_iam_account_alias.this.account_alias, "sem-alias")
    user          = aws_iam_user.site.name
    id            = aws_iam_access_key.site.id
    key           = aws_iam_access_key.site.secret
  }
  sensitive = true
}