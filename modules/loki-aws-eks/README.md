# Modulo Loki para OpenTofu

Instala o Loki em um cluster EKS usando Helm, sem IRSA, com storage em S3.

## Modos suportados

- `storage.create_bucket = true`: cria bucket S3, policy IAM, user IAM e access key para o Loki.
- `storage.create_bucket = false`: usa bucket existente e exige credenciais AWS informadas em `s3_auth.existing`.

## Requisitos

- Provider `aws` configurado na conta/regiao corretas.
- Provider `helm` configurado com acesso ao cluster EKS.
- O chart do Loki sera instalado no namespace informado.

## Exemplo criando bucket e credencial

```hcl
module "loki" {
  source = "./modulos-tofu/loki"

  eks_cluster_name = "meu-eks"

  tags = {
    Ambiente = "prod"
    App      = "loki"
  }

  storage = {
    create_bucket = true
    bucket_name   = "meu-loki-chunks"
  }

  s3_auth = {
    create_credentials = true
    created = {
      iam_user_name   = "loki-s3"
      iam_policy_name = "loki-s3"
    }
  }
}
```

## Exemplo reutilizando bucket e credencial

```hcl
module "loki" {
  source = "./modulos-tofu/loki"

  eks_cluster_name = "meu-eks"

  storage = {
    create_bucket     = false
    bucket_name       = "meu-loki-chunks"
    ruler_bucket_name = "meu-loki-ruler"
  }

  s3_auth = {
    create_credentials = false
    existing = {
      access_key_id     = var.loki_s3_access_key_id
      secret_access_key = var.loki_s3_secret_access_key
    }
  }

  values_override = {
    gateway = {
      service = {
        type = "LoadBalancer"
      }
    }
  }
}
```
