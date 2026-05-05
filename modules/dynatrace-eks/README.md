# Modulo Dynatrace para EKS

Instala o Dynatrace Operator e cria o recurso `DynaKube` em um cluster EKS, resolvendo automaticamente endpoint, CA e token do cluster a partir do provider AWS.

## Requisitos

- Provider `aws` autenticado na conta e regiao do cluster EKS.
- Permissao para ler `aws_eks_cluster` e `aws_eks_cluster_auth`.
- Acesso de rede ao endpoint do cluster EKS.

## O que o modulo faz

- Descobre o endpoint e o certificado do cluster EKS.
- Gera autenticacao Kubernetes a partir do token do EKS.
- Instala o `dynatrace-operator` via Helm.
- Cria o secret Kubernetes com `apiToken` e `dataIngestToken`.
- Cria o recurso customizado `DynaKube`.
- Configura o nome do cluster exibido no Dynatrace.

## Exemplo

```hcl
module "dynatrace" {
  source = "./modules/dynatrace-eks"

  eks_cluster_name = "meu-eks-prod"
  tenant_url       = "https://abc123.live.dynatrace.com/api"

  tokens = {
    api_token         = var.dynatrace_api_token
    data_ingest_token = var.dynatrace_data_ingest_token
  }
}
```

## Observacoes

- `cluster_name` e opcional. Quando omitido, o nome exibido no Dynatrace sera o mesmo de `eks_cluster_name`.
- O modulo requer apenas o provider `aws` configurado no root module; os providers `helm` e `kubernetes` sao configurados internamente a partir do EKS.
