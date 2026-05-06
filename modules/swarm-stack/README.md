# swarm-stack

Modulo Terraform para publicar artefatos de um stack Docker Swarm junto com a atualizacao da infraestrutura.

## Como funciona

1. O modulo calcula um hash dos arquivos do stack.
2. Copia o diretorio de artefatos para um manager do Swarm via SSH.
3. Executa `docker stack deploy` quando houver mudanca nos artefatos ou nos parametros relevantes.
4. Ao destruir o recurso no Terraform/OpenTofu, executa `docker stack rm` e opcionalmente limpa os artefatos remotos.

## Uso

```hcl
module "portainer" {
  source = "../../modules/swarm-stack"

  stack_name    = "portainer"
  artifact_path = "${path.module}/stacks/portainer"
  compose_file  = "docker-compose.yml"
  env_file      = ".env"
  connection = {
    manager_host                 = var.manager_host
    ssh_user                     = var.ssh_user
    ssh_private_key_path         = var.ssh_private_key_path
    ssh_strict_host_key_checking = false
  }
  deployment_triggers = {
    manager_instance_id = module.cluster_manager.instance_id
  }

  depends_on = [
    module.cluster_manager
  ]
}
```

## Dependencias

No host que roda o Terraform:

- Terraform/OpenTofu 1.4+
- `ssh` e `scp` disponiveis no PATH
- Acesso de rede ao manager do Swarm na porta SSH

No manager remoto:

- SSH habilitado
- `docker` instalado
- O host remoto precisa ser um manager ativo do Docker Swarm

## Observacoes operacionais

- Sim, SSH e necessario neste desenho, porque o Terraform precisa copiar os artefatos para o manager e executar `docker stack deploy`.
- O modulo aceita `connection` como objeto agrupado. As variaveis soltas antigas (`manager_host`, `ssh_user`, `ssh_port`, etc.) continuam suportadas por compatibilidade.
- O modulo nao armazena o conteudo da chave privada SSH no state. O recomendado e passar apenas `ssh_private_key_path` ou usar `ssh-agent`.
- Na remocao do recurso, o modulo espera a stack desaparecer do Swarm. Se a stack ja tiver sido removida manualmente, a destruicao segue normalmente.
- Para imagens privadas, use `with_registry_auth = true` e garanta que o manager ja tenha autenticacao valida no registry.
- O arquivo `env_file`, quando usado, deve ser shell-compatible porque ele e carregado com `. arquivo.env`.
- Para sincronizar deploy de stack com criacao ou troca da VM, use `deployment_triggers` com valores da infra, como `instance_id`, `private_ip`, `launch_template_version` ou outro identificador relevante. `depends_on` sozinho so garante a ordem.
- `extra_files` aceita um mapa de caminho relativo → conteudo como string. Use junto com `templatefile()`, `jsonencode()` ou qualquer funcao que produza texto para adicionar arquivos gerados programaticamente ao artefato sem precisar gravá-los em disco. O conteudo e transmitido via base64 por SSH, portanto e seguro para qualquer tipo de texto. Mudancas em `extra_files` automaticamente disparam redeploy via `artifact_hash`.

```hcl
module "minha_stack" {
  source        = "../../modules/swarm-stack"
  stack_name    = "minha-app"
  artifact_path = "${path.module}/stacks/minha-app"
  connection    = { manager_host = var.manager_host }

  extra_files = {
    "nginx.conf"         = templatefile("${path.module}/templates/nginx.conf.tftpl", { domain = var.domain })
    "config/app.json"    = jsonencode({ env = var.env, version = var.app_version })
  }
}
```
