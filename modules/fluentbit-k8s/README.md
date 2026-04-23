# Modulo Fluent Bit para OpenTofu

Instala o Fluent Bit em um cluster EKS usando o chart Helm oficial `fluent/fluent-bit`.

## Exemplo

```hcl
module "fluentbit" {
  source = "../modulos-tofu/fluentbit"

  eks_cluster_name = var.eks_cluster_name

  namespace         = "logging"
  create_namespace  = true
  helm_release_name = "fluent-bit"

  config = {
    service = file("${path.module}/fluentbit-service.conf")
    inputs  = file("${path.module}/fluentbit-inputs.conf")
    filters = file("${path.module}/fluentbit-filters.conf")
    outputs = templatefile("${path.module}/fluentbit-outputs.conf.tftpl", {
      loki_host = local.loki_host_value
      loki_port = local.loki_port_value
    })
    custom_parsers = file("${path.module}/fluentbit-custom-parsers.conf")
  }

  lua_scripts = {
    "workload.lua" = templatefile("${path.module}/workload.lua.tftpl", {
      cluster_name = var.eks_cluster_name
    })
  }
}
```

O arquivo `workload.lua` e montado em `/fluent-bit/scripts/workload.lua`, entao o filtro Lua deve referenciar esse caminho:

```ini
[FILTER]
    Name lua
    Match kube.*
    script /fluent-bit/scripts/workload.lua
    call derive_workload
```

Exemplo de `fluentbit-filters.conf`:

```ini
[FILTER]
    Name multiline
    Match kube.*
    multiline.key_content log
    multiline.parser java_stacktrace

[FILTER]
    Name kubernetes
    Match kube.*
    Kube_Tag_Prefix kube.var.log.containers.
    Merge_Log On
    Keep_Log Off
    K8S-Logging.Parser On
    K8S-Logging.Exclude On

[FILTER]
    Name lua
    Match kube.*
    script /fluent-bit/scripts/workload.lua
    call derive_workload

[FILTER]
    Name grep
    Match kube.*
    Regex $kubernetes['namespace_name'] ^(windson.*|logging|logging-test|logging-test-python)$
```

Use `values_override` para sobrescrever qualquer configuracao do chart sem alterar o modulo.
