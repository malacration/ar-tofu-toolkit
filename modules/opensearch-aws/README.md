# opensearch-aws

Provisiona um domínio **AWS OpenSearch Service** com criptografia habilitada e fine-grained access control, e exporta configurações prontas para integração com os módulos **fluentbit-k8s** e **grafana-k8s**.

## Arquitetura

```
Pods do EKS
   │
   ▼
fluentbit-k8s  ──(HTTPS + Basic Auth)──▶  AWS OpenSearch Domain
                                                   │
                                         grafana-k8s (plugin grafana-opensearch-datasource)
```

## Funcionalidades

- Domínio OpenSearch com **encrypt-at-rest** e **node-to-node encryption**
- HTTPS obrigatório com TLS 1.2+
- Fine-grained access control com usuário master interno
- Suporte a deploy **público** ou dentro de **VPC**
- Output `fluentbit_output_config` pronto para colar no módulo `fluentbit-k8s`
- Output `grafana_datasource` compatível com o módulo `grafana-k8s`

## Uso básico (domínio público)

```hcl
module "opensearch" {
  source = "path/to/modules/opensearch-aws"

  domain_name = "meu-cluster-logs"

  master_user = {
    username = "admin"
    password = var.opensearch_password
  }

  tags = {
    Environment = "production"
  }
}

# Conectar o FluentBit ao OpenSearch
module "fluentbit" {
  source = "path/to/modules/fluentbit-k8s"

  eks_cluster_name = var.cluster_name

  config = {
    service        = "[SERVICE]\n    Flush 5\n    Daemon Off\n    Log_Level info"
    inputs         = "[INPUT]\n    Name tail\n    Path /var/log/containers/*.log\n    multiline.parser docker, cri\n    Tag kube.*\n    Mem_Buf_Limit 5MB"
    filters        = ""
    outputs        = module.opensearch.fluentbit_output_config
    custom_parsers = ""
  }

  lua_scripts = {}
}

# Conectar o Grafana ao OpenSearch
module "grafana" {
  source = "path/to/modules/grafana-k8s"

  opensearch_datasources = [
    merge(module.opensearch.grafana_datasource, {
      basic_auth_user  = "admin"
      secure_json_data = { basicAuthPassword = var.opensearch_password }
    })
  ]
}
```

## Uso com VPC

```hcl
module "opensearch" {
  source = "path/to/modules/opensearch-aws"

  domain_name = "meu-cluster-logs"

  instance = {
    type             = "r6g.large.search"
    count            = 3
    dedicated_master = true
    master_type      = "r6g.large.search"
    master_count     = 3
    zone_awareness   = true
    availability_zones = 3
  }

  storage = {
    volume_type = "gp3"
    volume_size = 100
    iops        = 3000
    throughput  = 125
  }

  network = {
    vpc_id              = var.vpc_id
    subnet_ids          = var.private_subnet_ids
    allowed_cidr_blocks = [var.vpc_cidr]
  }

  master_user = {
    username = "admin"
    password = var.opensearch_password
  }

  tags = {
    Environment = "production"
  }
}
```

## Inputs

| Nome | Descrição | Tipo | Default | Obrigatório |
|------|-----------|------|---------|-------------|
| `domain_name` | Nome do domínio OpenSearch | `string` | - | sim |
| `engine_version` | Versão do engine (ex: `OpenSearch_2.13`) | `string` | `"OpenSearch_2.13"` | não |
| `instance` | Configuração das instâncias | `object` | `{}` | não |
| `storage` | Configuração EBS | `object` | `{}` | não |
| `network` | Configuração de rede/VPC | `object` | `{}` | não |
| `master_user` | Usuário e senha master (FGAC) | `object` | - | sim |
| `log_index` | Prefixo do índice de logs | `string` | `"logs"` | não |
| `log_index_date_format` | Formato de data do sufixo do índice | `string` | `"%Y.%m.%d"` | não |
| `tags` | Tags AWS | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição | Sensitive |
|------|-----------|-----------|
| `domain_name` | Nome do domínio | não |
| `domain_arn` | ARN do domínio | não |
| `endpoint` | Endpoint (sem https://) | não |
| `endpoint_url` | URL completa HTTPS | não |
| `engine_version` | Versão provisionada | não |
| `log_index` | Prefixo do índice configurado | não |
| `fluentbit_output_config` | Bloco OUTPUT para o fluentbit-k8s | **sim** |
| `grafana_datasource` | Objeto para `opensearch_datasources` do grafana-k8s | **sim** |
