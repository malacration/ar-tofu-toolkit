terraform {
  required_version = ">= 1.4.0"
}

locals {
  artifact_source_dir               = abspath(var.artifact_path)
  compose_file_path                 = "${local.artifact_source_dir}/${var.compose_file}"
  artifact_dir_name                 = basename(local.artifact_source_dir)
  artifact_files                    = sort(fileset(local.artifact_source_dir, "**"))
  artifact_hash                     = sha256(join("\n", [for file in local.artifact_files : "${file}:${filesha256("${local.artifact_source_dir}/${file}")}"]))
  env_file_value                    = var.env_file != null ? var.env_file : ""
  env_file_path                     = local.env_file_value != "" ? "${local.artifact_source_dir}/${local.env_file_value}" : null
  env_file_lines                    = local.env_file_path != null && fileexists(local.env_file_path) ? split("\n", file(local.env_file_path)) : []
  compose_env_map = {
    for line in local.env_file_lines :
    trimspace(trimprefix(split("=", trimspace(line))[0], "export ")) => trimsuffix(trimsuffix(trimprefix(trimprefix(trimspace(join("=", slice(split("=", trimspace(line)), 1, length(split("=", trimspace(line)))))), "\""), "'"), "\""), "'")
    if trimspace(line) != "" && !startswith(trimspace(line), "#") && length(split("=", trimspace(line))) > 1
  }
  manager_host_value                = try(var.connection.manager_host, null) != null ? var.connection.manager_host : var.manager_host
  ssh_user_value                    = coalesce(try(var.connection.ssh_user, null), var.ssh_user, "root")
  ssh_port_value                    = coalesce(try(var.connection.ssh_port, null), var.ssh_port, 22)
  ssh_timeout_value                 = coalesce(try(var.connection.ssh_timeout, null), var.ssh_timeout, "2m")
  ssh_strict_host_key_checking_bool = coalesce(try(var.connection.ssh_strict_host_key_checking, null), var.ssh_strict_host_key_checking, false)
  normalized_remote_dir             = trimsuffix(var.remote_base_dir, "/")
  remote_stack_dir                  = "${local.normalized_remote_dir}/${var.stack_name}"
  remote_release_dir                = "${local.remote_stack_dir}/current"
  ssh_private_key_path_raw          = try(var.connection.ssh_private_key_path, null) != null ? var.connection.ssh_private_key_path : (var.ssh_private_key_path != null ? var.ssh_private_key_path : "")
  ssh_private_key_path_value        = local.ssh_private_key_path_raw != "" ? pathexpand(local.ssh_private_key_path_raw) : ""
  ssh_strict_host_key_checking_flag = local.ssh_strict_host_key_checking_bool ? "yes" : "no"
  deploy_args = concat(
    ["-c ${local.remote_release_dir}/${var.compose_file}"],
    var.prune ? ["--prune"] : [],
    var.with_registry_auth ? ["--with-registry-auth"] : [],
    var.additional_deploy_args
  )
  deploy_args_rebased = join(" ", [for arg in local.deploy_args : replace(arg, local.remote_release_dir, "$DEPLOY_DIR")])
  compose_services      = try(yamldecode(file(local.compose_file_path)).services, {})
  traefik_routes_flat = concat(
    local.detected_traefik_routes,
    [
      for route in var.traefik_routes : {
        stack   = var.stack_name
        service = route.service
        router  = route.service
        hosts   = route.hosts
      }
    ]
  )
  traefik_service_names = sort(distinct(concat(
    keys(local.compose_services),
    [for route in local.traefik_routes_flat : route.service]
  )))
  traefik_routes_by_stack = {
    (var.stack_name) = {
      for service_name in local.traefik_service_names :
      service_name => {
        rotas = sort(distinct(flatten([
          for route in local.traefik_routes_flat : route.hosts
          if route.service == service_name
        ])))
      }
    }
  }
  detected_traefik_routes = flatten([
    for service_name, service in local.compose_services : [
      for router_name, rule in {
        for key, value in merge(
          { for label in concat(
            [for item in try(tolist(try(service.deploy.labels, [])), []) : tostring(item)],
            [for item in try(tolist(try(service.labels, [])), []) : tostring(item)],
            [for k, v in try(tomap(try(service.deploy.labels, {})), {}) : "${k}=${v}"],
            [for k, v in try(tomap(try(service.labels, {})), {}) : "${k}=${v}"]
          ) :
            trimspace(split("=", label)[0]) => trimspace(join("=", slice(split("=", label), 1, length(split("=", label)))))
            if length(split("=", label)) > 1
          }
        ) :
        trimsuffix(trimprefix(key, "traefik.http.routers."), ".rule") => value
        if startswith(key, "traefik.http.routers.") && endswith(key, ".rule")
      } : {
        stack   = var.stack_name
        service = lookup({
          for key, value in merge(
            { for label in concat(
              [for item in try(tolist(try(service.deploy.labels, [])), []) : tostring(item)],
              [for item in try(tolist(try(service.labels, [])), []) : tostring(item)],
              [for k, v in try(tomap(try(service.deploy.labels, {})), {}) : "${k}=${v}"],
              [for k, v in try(tomap(try(service.labels, {})), {}) : "${k}=${v}"]
            ) :
              trimspace(split("=", label)[0]) => trimspace(join("=", slice(split("=", label), 1, length(split("=", label)))))
              if length(split("=", label)) > 1
            }
          ) :
          trimsuffix(trimprefix(key, "traefik.http.routers."), ".service") => value
          if startswith(key, "traefik.http.routers.") && endswith(key, ".service")
        }, router_name, service_name)
        router = router_name
        hosts = [
          for match in regexall("Host\\(`([^`]+)`\\)", rule) :
          lookup(
            local.compose_env_map,
            trimsuffix(trimprefix(match[0], "$${"), "}"),
            match[0]
          )
        ]
      }
      if length(regexall("Host\\(`([^`]+)`\\)", rule)) > 0
    ]
  ])
}

resource "terraform_data" "deploy" {
  depends_on = [terraform_data.stack_cleanup]

  triggers_replace = {
    artifact_hash                   = local.artifact_hash
    compose_file                    = var.compose_file
    env_file                        = local.env_file_value
    remote_base_dir                 = var.remote_base_dir
    stack_name                      = var.stack_name
    prune                           = tostring(var.prune)
    with_registry_auth              = tostring(var.with_registry_auth)
    additional_commands             = jsonencode(var.additional_deploy_args)
    deployment_triggers             = jsonencode(var.deployment_triggers)
    remove_remote_artifacts_destroy = tostring(var.remove_remote_artifacts_on_destroy)
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = local.manager_host_value != null
      error_message = "Informe connection.manager_host ou manager_host para o swarm-stack."
    }
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
      ARTIFACT_SOURCE_DIR="${local.artifact_source_dir}"
      REMOTE_BASE_DIR="${local.normalized_remote_dir}"
      REMOTE_RELEASE_DIR="${local.remote_release_dir}"
      ARTIFACT_DIR_NAME="${local.artifact_dir_name}"
      COMPOSE_FILE="${var.compose_file}"
      ENV_FILE="${local.env_file_value}"
      STACK_NAME="${var.stack_name}"

      ssh_args=(-p "$PORT" -o BatchMode=yes)
      scp_args=(-P "$PORT" -o BatchMode=yes)

      if [ -n "$SSH_KEY_PATH" ]; then
        ssh_args=(-i "$SSH_KEY_PATH" "$${ssh_args[@]}")
        scp_args=(-i "$SSH_KEY_PATH" "$${scp_args[@]}")
      fi

      if [ "$STRICT_HOST_KEY_CHECKING" = "yes" ]; then
        ssh_args+=(-o StrictHostKeyChecking=yes)
        scp_args+=(-o StrictHostKeyChecking=yes)
      else
        ssh_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
        scp_args+=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
      fi

      run_ssh() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        else
          ssh "$${ssh_args[@]}" "$USER@$HOST" "$@"
        fi
      }

      run_scp() {
        if command -v timeout >/dev/null 2>&1; then
          timeout "$SSH_TIMEOUT" scp "$${scp_args[@]}" -r "$ARTIFACT_SOURCE_DIR" "$USER@$HOST:$REMOTE_RELEASE_DIR"
        else
          scp "$${scp_args[@]}" -r "$ARTIFACT_SOURCE_DIR" "$USER@$HOST:$REMOTE_RELEASE_DIR"
        fi
      }

      run_ssh "set -e; command -v docker >/dev/null 2>&1 || { echo 'docker nao encontrado no host remoto'; exit 1; }; docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}' | grep -q '^active true$' || { echo 'o host remoto precisa ser um manager ativo do Docker Swarm'; exit 1; }; mkdir -p '$REMOTE_BASE_DIR'; rm -rf '$REMOTE_RELEASE_DIR'; mkdir -p '$REMOTE_RELEASE_DIR'"
      run_scp

      run_ssh "DEPLOY_BASE='$REMOTE_RELEASE_DIR' COMPOSE_FILE='$COMPOSE_FILE' ARTIFACT_DIR='$ARTIFACT_DIR_NAME' ENV_FILE='$ENV_FILE' STACK_NAME='$STACK_NAME' bash -s" <<'REMOTE'
      set -e

      DEPLOY_DIR="$DEPLOY_BASE"
      if [ ! -f "$DEPLOY_DIR/$COMPOSE_FILE" ] && [ -f "$DEPLOY_DIR/$ARTIFACT_DIR/$COMPOSE_FILE" ]; then
        DEPLOY_DIR="$DEPLOY_DIR/$ARTIFACT_DIR"
      fi

      test -f "$DEPLOY_DIR/$COMPOSE_FILE" || { echo 'compose file nao encontrado no artefato enviado'; exit 1; }

      if [ -n "$ENV_FILE" ]; then
        test -f "$DEPLOY_DIR/$ENV_FILE" || { echo 'env file nao encontrado no artefato enviado'; exit 1; }
      fi

      ENV_LOAD=':'
      if [ -n "$ENV_FILE" ]; then
        ENV_LOAD="set -a && . \"$DEPLOY_DIR/$ENV_FILE\" && set +a"
      fi

      cd "$DEPLOY_DIR"
      sh -lc "$ENV_LOAD && docker stack deploy ${local.deploy_args_rebased} $STACK_NAME"
      REMOTE
    EOT
  }
}

resource "terraform_data" "stack_cleanup" {
  input = {
    manager_host                       = local.manager_host_value
    ssh_user                           = local.ssh_user_value
    ssh_port                           = tostring(local.ssh_port_value)
    ssh_private_key_path               = local.ssh_private_key_path_value
    ssh_timeout                        = local.ssh_timeout_value
    ssh_strict_host_key_checking       = local.ssh_strict_host_key_checking_flag
    stack_name                         = var.stack_name
    remote_stack_dir                   = local.remote_stack_dir
    remove_remote_artifacts_on_destroy = tostring(var.remove_remote_artifacts_on_destroy)
  }

  triggers_replace = {
    remote_base_dir                 = var.remote_base_dir
    stack_name                      = var.stack_name
    remove_remote_artifacts_destroy = tostring(var.remove_remote_artifacts_on_destroy)
  }

  provisioner "local-exec" {
    when = destroy

    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      HOST="${try(self.input.manager_host, self.triggers_replace["manager_host"])}"
      USER="${try(self.input.ssh_user, try(self.triggers_replace["ssh_user"], "root"))}"
      PORT="${try(self.input.ssh_port, try(self.triggers_replace["ssh_port"], "22"))}"
      SSH_KEY_PATH="${try(self.input.ssh_private_key_path, try(self.triggers_replace["ssh_private_key_path"], ""))}"
      SSH_TIMEOUT="${try(self.input.ssh_timeout, try(self.triggers_replace["ssh_timeout"], "2m"))}"
      STRICT_HOST_KEY_CHECKING="${try(self.input.ssh_strict_host_key_checking, try(self.triggers_replace["ssh_strict_host_key_checking"], "no"))}"
      STACK_NAME="${try(self.input.stack_name, self.triggers_replace["stack_name"])}"
      STACK_DIR="${try(self.input.remote_stack_dir, "${self.triggers_replace["remote_base_dir"]}/${self.triggers_replace["stack_name"]}")}"
      REMOVE_REMOTE_ARTIFACTS="${try(self.input.remove_remote_artifacts_on_destroy, try(self.triggers_replace["remove_remote_artifacts_destroy"], "true"))}"

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

      run_ssh "STACK_NAME='$STACK_NAME' STACK_DIR='$STACK_DIR' REMOVE_REMOTE_ARTIFACTS='$REMOVE_REMOTE_ARTIFACTS' bash -s" <<'REMOTE'
      set -e

      stack_exists() {
        docker stack ls --format '{{.Name}}' | grep -Fx "$STACK_NAME" >/dev/null 2>&1
      }

      cleanup_artifacts() {
        if [ "$REMOVE_REMOTE_ARTIFACTS" = "true" ]; then
          rm -rf "$STACK_DIR"
        fi
      }

      if stack_exists; then
        docker stack rm "$STACK_NAME"
      fi

      for attempt in $(seq 1 30); do
        if ! stack_exists; then
          cleanup_artifacts
          exit 0
        fi
        sleep 2
      done

      if stack_exists; then
        echo 'falha ao remover a stack do swarm'
        exit 1
      fi

      cleanup_artifacts
      REMOTE
    EOT
  }
}
