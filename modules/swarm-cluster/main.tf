terraform {
  required_version = ">= 1.4.0"
}

locals {
  ssh_user_default                    = coalesce(try(var.connection_defaults.ssh_user, null), "root")
  ssh_port_default                    = coalesce(try(var.connection_defaults.ssh_port, null), 22)
  ssh_timeout_value                   = coalesce(try(var.connection_defaults.ssh_timeout, null), var.ssh_timeout, "2m")
  ssh_strict_host_key_checking_bool   = coalesce(try(var.connection_defaults.ssh_strict_host_key_checking, null), var.ssh_strict_host_key_checking, false)
  ssh_private_key_path_raw            = try(var.connection_defaults.ssh_private_key_path, null) != null ? var.connection_defaults.ssh_private_key_path : (var.ssh_private_key_path != null ? var.ssh_private_key_path : "")
  resolved_ssh_private_key_path       = local.ssh_private_key_path_raw != "" ? pathexpand(local.ssh_private_key_path_raw) : ""
  strict_host_key_checking_flag_value = local.ssh_strict_host_key_checking_bool ? "yes" : "no"

  normalized_manager_hosts = [
    for host in var.manager_hosts : {
      host           = host.host
      ssh_user       = coalesce(try(host.ssh_user, null), local.ssh_user_default)
      ssh_port       = coalesce(try(host.ssh_port, null), local.ssh_port_default)
      advertise_addr = coalesce(try(host.advertise_addr, null), host.host)
      listen_addr    = try(host.listen_addr, null)
      node_name      = try(host.node_name, null)
    }
  ]

  normalized_worker_hosts = [
    for host in var.worker_hosts : {
      host           = host.host
      ssh_user       = coalesce(try(host.ssh_user, null), local.ssh_user_default)
      ssh_port       = coalesce(try(host.ssh_port, null), local.ssh_port_default)
      advertise_addr = coalesce(try(host.advertise_addr, null), host.host)
      node_name      = try(host.node_name, null)
    }
  ]

  primary_manager          = local.normalized_manager_hosts[0]
  primary_manager_endpoint = local.primary_manager.advertise_addr
  secondary_managers = {
    for host in slice(local.normalized_manager_hosts, 1, length(local.normalized_manager_hosts)) :
    host.host => host
  }
  worker_nodes = {
    for host in local.normalized_worker_hosts :
    host.host => host
  }
  cluster_members_hash = sha1(jsonencode({
    managers = local.normalized_manager_hosts
    workers  = local.normalized_worker_hosts
  }))
}

resource "terraform_data" "validation" {
  input = true

  lifecycle {
    precondition {
      condition     = length(var.manager_hosts) > 0
      error_message = "Informe pelo menos um host manager."
    }

    precondition {
      condition     = length(distinct([for host in local.normalized_manager_hosts : host.host])) == length(local.normalized_manager_hosts)
      error_message = "Cada manager host precisa ser unico."
    }

    precondition {
      condition     = length(distinct([for host in local.normalized_worker_hosts : host.host])) == length(local.normalized_worker_hosts)
      error_message = "Cada worker host precisa ser unico."
    }

    precondition {
      condition = length(setintersection(
        toset([for host in local.normalized_manager_hosts : host.host]),
        toset([for host in local.normalized_worker_hosts : host.host])
      )) == 0
      error_message = "Um mesmo host nao pode existir como manager e worker ao mesmo tempo."
    }
  }
}

resource "terraform_data" "bootstrap_manager" {
  depends_on = [terraform_data.validation]

  input = merge(local.primary_manager, {
    listen_addr              = local.primary_manager.listen_addr != null ? local.primary_manager.listen_addr : ""
    ssh_private_key_path     = local.resolved_ssh_private_key_path
    ssh_timeout              = local.ssh_timeout_value
    strict_host_key_checking = local.strict_host_key_checking_flag_value
  })

  triggers_replace = {
    host           = local.primary_manager.host
    advertise_addr = local.primary_manager.advertise_addr
    listen_addr    = local.primary_manager.listen_addr != null ? local.primary_manager.listen_addr : ""
    swarm_port     = tostring(var.swarm_port)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SSH_KEY="${self.input.ssh_private_key_path}"
      HOST="${self.input.host}"
      USER="${self.input.ssh_user}"
      PORT="${self.input.ssh_port}"
      ADVERTISE_ADDR="${self.input.advertise_addr}"
      LISTEN_ADDR="${self.input.listen_addr}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"
      STRICT_HOST_KEY_CHECKING="${self.input.strict_host_key_checking}"

      ssh_args=(-p "$PORT" -o BatchMode=yes)
      if [ -n "$SSH_KEY" ]; then
        ssh_args=(-i "$SSH_KEY" "$${ssh_args[@]}")
      fi
      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      remote() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        else
          ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        fi
      }

      remote "command -v docker >/dev/null 2>&1 || { echo docker nao encontrado no host remoto; exit 1; }"

      STATE="$(remote "docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}' 2>/dev/null || true")"
      if [ "$STATE" = "active true" ]; then
        exit 0
      fi

      if [ "$STATE" = "active false" ]; then
        remote "docker swarm leave --force || true"
      fi

      INIT_CMD="docker swarm init --advertise-addr '$ADVERTISE_ADDR'"
      if [ -n "$LISTEN_ADDR" ]; then
        INIT_CMD="$INIT_CMD --listen-addr '$LISTEN_ADDR'"
      fi

      remote "$INIT_CMD"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SSH_KEY="${self.input.ssh_private_key_path}"
      HOST="${self.input.host}"
      USER="${self.input.ssh_user}"
      PORT="${self.input.ssh_port}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"
      STRICT_HOST_KEY_CHECKING="${self.input.strict_host_key_checking}"

      ssh_args=(-p "$PORT" -o BatchMode=yes)
      if [ -n "$SSH_KEY" ]; then
        ssh_args=(-i "$SSH_KEY" "$${ssh_args[@]}")
      fi
      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      if command -v timeout >/dev/null 2>&1; then
        timeout "$SSH_TIMEOUT" ssh "$${ssh_args[@]}" "$USER@$HOST" "docker swarm leave --force || true" || true
      else
        ssh "$${ssh_args[@]}" "$USER@$HOST" "docker swarm leave --force || true" || true
      fi
    EOT
  }
}

resource "terraform_data" "manager_join" {
  for_each = local.secondary_managers

  depends_on = [terraform_data.bootstrap_manager]

  input = {
    host                     = each.value.host
    ssh_user                 = each.value.ssh_user
    ssh_port                 = each.value.ssh_port
    advertise_addr           = each.value.advertise_addr
    node_name                = each.value.node_name != null ? each.value.node_name : ""
    role                     = "manager"
    primary_host             = local.primary_manager.host
    primary_ssh_user         = local.primary_manager.ssh_user
    primary_ssh_port         = local.primary_manager.ssh_port
    primary_endpoint         = local.primary_manager_endpoint
    ssh_timeout              = local.ssh_timeout_value
    ssh_private_key_path     = local.resolved_ssh_private_key_path
    strict_host_key_checking = local.strict_host_key_checking_flag_value
  }

  triggers_replace = {
    host             = each.value.host
    advertise_addr   = each.value.advertise_addr
    node_name        = each.value.node_name != null ? each.value.node_name : ""
    role             = "manager"
    primary_host     = local.primary_manager.host
    primary_endpoint = local.primary_manager_endpoint
    swarm_port       = tostring(var.swarm_port)
    bootstrap_id     = terraform_data.bootstrap_manager.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SSH_KEY="${self.input.ssh_private_key_path}"
      STRICT_HOST_KEY_CHECKING="${self.input.strict_host_key_checking}"
      TARGET_HOST="${self.input.host}"
      TARGET_USER="${self.input.ssh_user}"
      TARGET_PORT="${self.input.ssh_port}"
      TARGET_ADVERTISE_ADDR="${self.input.advertise_addr}"
      ROLE="${self.input.role}"
      PRIMARY_HOST="${self.input.primary_host}"
      PRIMARY_USER="${self.input.primary_ssh_user}"
      PRIMARY_PORT="${self.input.primary_ssh_port}"
      PRIMARY_ENDPOINT="${self.input.primary_endpoint}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"
      SWARM_PORT="${var.swarm_port}"

      primary_ssh_args=(-p "$PRIMARY_PORT" -o BatchMode=yes)
      target_ssh_args=(-p "$TARGET_PORT" -o BatchMode=yes)
      if [ -n "$SSH_KEY" ]; then
        primary_ssh_args=(-i "$SSH_KEY" "$${primary_ssh_args[@]}")
        target_ssh_args=(-i "$SSH_KEY" "$${target_ssh_args[@]}")
      fi
      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        primary_ssh_args+=(-o StrictHostKeyChecking=yes)
        target_ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        primary_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
        target_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      remote_primary() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        else
          ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        fi
      }

      remote_target() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        else
          ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        fi
      }

      remote_target "command -v docker >/dev/null 2>&1 || { echo docker nao encontrado no host remoto; exit 1; }"

      TARGET_STATE="$(remote_target "docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}' 2>/dev/null || true")"
      if [ "$TARGET_STATE" = "active true" ]; then
        exit 0
      fi

      if [ "$TARGET_STATE" = "active false" ]; then
        remote_target "docker swarm leave --force || true"
      fi

      JOIN_TOKEN="$(remote_primary "docker swarm join-token -q $ROLE")"
      JOIN_CMD="docker swarm join --token '$JOIN_TOKEN' '$PRIMARY_ENDPOINT:$SWARM_PORT' --advertise-addr '$TARGET_ADVERTISE_ADDR'"
      remote_target "$JOIN_CMD"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SSH_KEY="${self.input.ssh_private_key_path}"
      STRICT_HOST_KEY_CHECKING="${self.input.strict_host_key_checking}"
      TARGET_HOST="${self.input.host}"
      TARGET_USER="${self.input.ssh_user}"
      TARGET_PORT="${self.input.ssh_port}"
      TARGET_NODE_NAME="${self.input.node_name}"
      PRIMARY_HOST="${self.input.primary_host}"
      PRIMARY_USER="${self.input.primary_ssh_user}"
      PRIMARY_PORT="${self.input.primary_ssh_port}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"

      primary_ssh_args=(-p "$PRIMARY_PORT" -o BatchMode=yes)
      target_ssh_args=(-p "$TARGET_PORT" -o BatchMode=yes)
      if [ -n "$SSH_KEY" ]; then
        primary_ssh_args=(-i "$SSH_KEY" "$${primary_ssh_args[@]}")
        target_ssh_args=(-i "$SSH_KEY" "$${target_ssh_args[@]}")
      fi
      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        primary_ssh_args+=(-o StrictHostKeyChecking=yes)
        target_ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        primary_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
        target_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      remote_primary() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        else
          ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        fi
      }

      remote_target() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        else
          ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        fi
      }

      NODE_REF="$TARGET_NODE_NAME"
      NODE_ID="$(remote_target "docker info --format '{{if .Swarm.NodeID}}{{.Swarm.NodeID}}{{end}}' 2>/dev/null || true" || true)"
      if [ -n "$NODE_ID" ]; then
        NODE_REF="$NODE_ID"
      fi

      remote_target "docker swarm leave --force || true" || true

      if [ -n "$NODE_REF" ]; then
        remote_primary "docker node rm --force '$NODE_REF' || true" || true
      fi
    EOT
  }
}

resource "terraform_data" "worker_join" {
  for_each = local.worker_nodes

  depends_on = [terraform_data.bootstrap_manager]

  input = {
    host                     = each.value.host
    ssh_user                 = each.value.ssh_user
    ssh_port                 = each.value.ssh_port
    advertise_addr           = each.value.advertise_addr
    node_name                = each.value.node_name != null ? each.value.node_name : ""
    role                     = "worker"
    primary_host             = local.primary_manager.host
    primary_ssh_user         = local.primary_manager.ssh_user
    primary_ssh_port         = local.primary_manager.ssh_port
    primary_endpoint         = local.primary_manager_endpoint
    ssh_timeout              = local.ssh_timeout_value
    ssh_private_key_path     = local.resolved_ssh_private_key_path
    strict_host_key_checking = local.strict_host_key_checking_flag_value
  }

  triggers_replace = {
    host             = each.value.host
    advertise_addr   = each.value.advertise_addr
    node_name        = each.value.node_name != null ? each.value.node_name : ""
    role             = "worker"
    primary_host     = local.primary_manager.host
    primary_endpoint = local.primary_manager_endpoint
    swarm_port       = tostring(var.swarm_port)
    bootstrap_id     = terraform_data.bootstrap_manager.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SSH_KEY="${self.input.ssh_private_key_path}"
      STRICT_HOST_KEY_CHECKING="${self.input.strict_host_key_checking}"
      TARGET_HOST="${self.input.host}"
      TARGET_USER="${self.input.ssh_user}"
      TARGET_PORT="${self.input.ssh_port}"
      TARGET_ADVERTISE_ADDR="${self.input.advertise_addr}"
      ROLE="${self.input.role}"
      PRIMARY_HOST="${self.input.primary_host}"
      PRIMARY_USER="${self.input.primary_ssh_user}"
      PRIMARY_PORT="${self.input.primary_ssh_port}"
      PRIMARY_ENDPOINT="${self.input.primary_endpoint}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"
      SWARM_PORT="${var.swarm_port}"

      primary_ssh_args=(-p "$PRIMARY_PORT" -o BatchMode=yes)
      target_ssh_args=(-p "$TARGET_PORT" -o BatchMode=yes)
      if [ -n "$SSH_KEY" ]; then
        primary_ssh_args=(-i "$SSH_KEY" "$${primary_ssh_args[@]}")
        target_ssh_args=(-i "$SSH_KEY" "$${target_ssh_args[@]}")
      fi
      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        primary_ssh_args+=(-o StrictHostKeyChecking=yes)
        target_ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        primary_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
        target_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      remote_primary() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        else
          ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        fi
      }

      remote_target() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        else
          ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        fi
      }

      remote_target "command -v docker >/dev/null 2>&1 || { echo docker nao encontrado no host remoto; exit 1; }"

      TARGET_STATE="$(remote_target "docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}' 2>/dev/null || true")"
      if [ "$TARGET_STATE" = "active false" ]; then
        exit 0
      fi

      if [ "$TARGET_STATE" = "active true" ]; then
        remote_target "docker swarm leave --force || true"
      fi

      JOIN_TOKEN="$(remote_primary "docker swarm join-token -q $ROLE")"
      JOIN_CMD="docker swarm join --token '$JOIN_TOKEN' '$PRIMARY_ENDPOINT:$SWARM_PORT' --advertise-addr '$TARGET_ADVERTISE_ADDR'"
      remote_target "$JOIN_CMD"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SSH_KEY="${self.input.ssh_private_key_path}"
      STRICT_HOST_KEY_CHECKING="${self.input.strict_host_key_checking}"
      TARGET_HOST="${self.input.host}"
      TARGET_USER="${self.input.ssh_user}"
      TARGET_PORT="${self.input.ssh_port}"
      TARGET_NODE_NAME="${self.input.node_name}"
      PRIMARY_HOST="${self.input.primary_host}"
      PRIMARY_USER="${self.input.primary_ssh_user}"
      PRIMARY_PORT="${self.input.primary_ssh_port}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"

      primary_ssh_args=(-p "$PRIMARY_PORT" -o BatchMode=yes)
      target_ssh_args=(-p "$TARGET_PORT" -o BatchMode=yes)
      if [ -n "$SSH_KEY" ]; then
        primary_ssh_args=(-i "$SSH_KEY" "$${primary_ssh_args[@]}")
        target_ssh_args=(-i "$SSH_KEY" "$${target_ssh_args[@]}")
      fi
      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        primary_ssh_args+=(-o StrictHostKeyChecking=yes)
        target_ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        primary_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
        target_ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      remote_primary() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        else
          ssh "$${primary_ssh_args[@]}" "$PRIMARY_USER@$PRIMARY_HOST" "$@"
        fi
      }

      remote_target() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        else
          ssh "$${target_ssh_args[@]}" "$TARGET_USER@$TARGET_HOST" "$@"
        fi
      }

      NODE_REF="$TARGET_NODE_NAME"
      NODE_ID="$(remote_target "docker info --format '{{if .Swarm.NodeID}}{{.Swarm.NodeID}}{{end}}' 2>/dev/null || true" || true)"
      if [ -n "$NODE_ID" ]; then
        NODE_REF="$NODE_ID"
      fi

      remote_target "docker swarm leave --force || true" || true

      if [ -n "$NODE_REF" ]; then
        remote_primary "docker node rm --force '$NODE_REF' || true" || true
      fi
    EOT
  }
}
