# Modulo Dynatrace para Kubernetes

Instala o Dynatrace Operator via Helm e cria um recurso `DynaKube` com os tokens necessarios para conectar o cluster ao tenant Dynatrace.

## Requisitos

- Provider `helm` configurado com acesso ao cluster Kubernetes.
- Provider `kubernetes` configurado com acesso ao mesmo cluster.
- URL do tenant Dynatrace com o sufixo `/api`.
- Token do Dynatrace Operator e Data Ingest token.

## O que o modulo faz

- Instala o `dynatrace-operator` via chart Helm oficial.
- Cria o secret Kubernetes com `apiToken` e `dataIngestToken`.
- Cria o recurso customizado `DynaKube`.
- Configura o nome do cluster exibido no Dynatrace.

## Exemplo

```hcl
module "dynatrace" {
  source = "./modules/dynatrace-k8s"

  cluster_name = "meu-cluster-eks"
  tenant_url   = "https://abc123.live.dynatrace.com/api"

  tokens = {
    api_token         = var.dynatrace_api_token
    data_ingest_token = var.dynatrace_data_ingest_token
  }
}
```

## Observacoes

- Por padrao, o modulo habilita `kubernetes-monitoring` no ActiveGate.
- O nome exibido do cluster no Dynatrace e aplicado pela annotation `feature.dynatrace.com/automatic-kubernetes-api-monitoring-cluster-name`.
- O modulo desabilita o CSI driver do chart por padrao, alinhado com uma instalacao minima para monitoramento de Kubernetes.
