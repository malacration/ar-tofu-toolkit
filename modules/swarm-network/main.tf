terraform {
  required_version = ">= 1.4.0"
}

locals {
  manager_host_value                = try(var.connection.manager_host, null) != null ? var.connection.manager_host : var.manager_host
  ssh_user_value                    = coalesce(try(var.connection.ssh_user, null), var.ssh_user, "root")
  ssh_port_value                    = coalesce(try(var.connection.ssh_port, null), var.ssh_port, 22)
  ssh_timeout_value                 = coalesce(try(var.connection.ssh_timeout, null), var.ssh_timeout, "2m")
  ssh_strict_host_key_checking_bool = coalesce(try(var.connection.ssh_strict_host_key_checking, null), var.ssh_strict_host_key_checking, false)
  ssh_private_key_path_raw          = try(var.connection.ssh_private_key_path, null) != null ? var.connection.ssh_private_key_path : (var.ssh_private_key_path != null ? var.ssh_private_key_path : "")
  ssh_private_key_path_value        = local.ssh_private_key_path_raw != "" ? pathexpand(local.ssh_private_key_path_raw) : ""
  ssh_strict_host_key_checking_flag = local.ssh_strict_host_key_checking_bool ? "yes" : "no"
}

resource "terraform_data" "network" {
  input = {
    manager_host                 = local.manager_host_value
    ssh_user                     = local.ssh_user_value
    ssh_port                     = tostring(local.ssh_port_value)
    ssh_private_key_path         = local.ssh_private_key_path_value
    ssh_timeout                  = local.ssh_timeout_value
    ssh_strict_host_key_checking = local.ssh_strict_host_key_checking_flag
    network_name                 = var.network_name
    driver                       = var.driver
    attachable                   = tostring(var.attachable)
    remove_on_destroy            = tostring(var.remove_on_destroy)
  }

  triggers_replace = {
    network_name                 = var.network_name
    driver                       = var.driver
    attachable                   = tostring(var.attachable)
    remove_on_destroy            = tostring(var.remove_on_destroy)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      HOST="${local.manager_host_value}"
      USER="${local.ssh_user_value}"
      PORT="${local.ssh_port_value}"
      SSH_KEY_PATH="${local.ssh_private_key_path_value}"
      SSH_TIMEOUT="${local.ssh_timeout_value}"
      STRICT_HOST_KEY_CHECKING="${local.ssh_strict_host_key_checking_flag}"
      NETWORK_NAME="${var.network_name}"
      DRIVER="${var.driver}"
      ATTACHABLE="${var.attachable ? "true" : "false"}"

      ssh_args=(-p "$PORT" -o BatchMode=yes)

      if [ -n "$SSH_KEY_PATH" ]; then
        ssh_args=(-i "$SSH_KEY_PATH" "$${ssh_args[@]}")
      fi

      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      run_ssh() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        else
          ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        fi
      }

      run_ssh "NETWORK_NAME='$NETWORK_NAME' DRIVER='$DRIVER' ATTACHABLE='$ATTACHABLE' bash -s" <<'REMOTE'
      set -e

      if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        exit 0
      fi

      CREATE_CMD="docker network create --driver $DRIVER --scope swarm"
      if [ "$ATTACHABLE" = "true" ]; then
        CREATE_CMD="$CREATE_CMD --attachable"
      fi
      CREATE_CMD="$CREATE_CMD $NETWORK_NAME"

      sh -lc "$CREATE_CMD"
      REMOTE
    EOT
  }

  lifecycle {
    precondition {
      condition     = local.manager_host_value != null
      error_message = "Informe connection.manager_host ou manager_host para o swarm-network."
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      HOST="${self.input.manager_host}"
      USER="${self.input.ssh_user}"
      PORT="${self.input.ssh_port}"
      SSH_KEY_PATH="${self.input.ssh_private_key_path}"
      SSH_TIMEOUT="${self.input.ssh_timeout}"
      STRICT_HOST_KEY_CHECKING="${self.input.ssh_strict_host_key_checking}"
      NETWORK_NAME="${self.input.network_name}"
      REMOVE_ON_DESTROY="${self.input.remove_on_destroy}"

      ssh_args=(-p "$PORT" -o BatchMode=yes)

      if [ -n "$SSH_KEY_PATH" ]; then
        ssh_args=(-i "$SSH_KEY_PATH" "$${ssh_args[@]}")
      fi

      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        ssh_args+=(-o StrictHostKeyChecking=yes)
      else
        ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      run_ssh() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        else
          ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        fi
      }

      if [ "$REMOVE_ON_DESTROY" != "true" ]; then
        exit 0
      fi

      run_ssh "docker network rm '$NETWORK_NAME' >/dev/null 2>&1 || true"
    EOT
  }
}
