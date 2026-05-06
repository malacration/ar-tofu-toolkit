# swarm-cluster

Modulo Terraform para formar e manter um cluster Docker Swarm em hosts ja existentes.

## O que ele faz

1. Usa o primeiro item de `manager_hosts` como bootstrap manager.
2. Executa `docker swarm init` nesse host, se necessario.
3. Faz `join` dos demais managers.
4. Faz `join` dos workers.
5. Quando um host sai da configuracao, tenta executar `docker swarm leave` nele e `docker node rm --force` no manager principal.

## Requisitos

No host que roda o Terraform:

- `ssh` disponivel no PATH
- acesso SSH para todos os hosts informados

Nos hosts remotos:

- `docker` instalado
- conectividade entre os nos na porta `2377/tcp` para o join
- portas e protocolos do Swarm liberados entre os nos conforme a topologia do cluster

## Entradas

- `manager_hosts`: lista ordenada de managers. O primeiro e o manager principal.
- `worker_hosts`: lista de workers.
- `connection_defaults`: defaults de SSH aplicados aos hosts que nao sobrescreverem `ssh_user` ou `ssh_port`, alem de chave, timeout e verificacao de host key.

Cada host aceita:

- `host`
- `ssh_user`
- `ssh_port`
- `advertise_addr`
- `listen_addr` para managers
- `node_name` opcional para ajudar na limpeza do node quando o host nao estiver mais acessivel

## Exemplo

```hcl
module "cluster" {
  source = "../../modules/swarm-cluster"

  connection_defaults = {
    ssh_user                     = "root"
    ssh_private_key_path         = "~/.ssh/id_rsa"
    ssh_strict_host_key_checking = false
  }

  manager_hosts = [
    {
      host           = "10.0.1.10"
      advertise_addr = "10.0.1.10"
      node_name      = "swarm-manager-1"
    },
    {
      host           = "10.0.1.11"
      advertise_addr = "10.0.1.11"
      node_name      = "swarm-manager-2"
    }
  ]

  worker_hosts = [
    {
      host           = "10.0.1.20"
      advertise_addr = "10.0.1.20"
      node_name      = "swarm-worker-1"
    }
  ]
}
```

## Observacoes

- O modulo nao cria VMs. Ele forma o cluster sobre hosts que ja existem.
- Cada host ainda pode sobrescrever `ssh_user` e `ssh_port` individualmente quando algum no foge do padrao definido em `connection_defaults`.
- A ordem de `manager_hosts` importa: o primeiro host e o bootstrap manager.
- Trocar o primeiro manager depois de criado implica recriar a coordenacao do cluster.
- Para remover um host do cluster de forma limpa, ele ainda deve estar acessivel por SSH no momento do `apply`.
