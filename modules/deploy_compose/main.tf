# modules/deploy_compose/main.tf
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

data "aws_instance" "target" {
  instance_id = var.instance_id
}

locals {
  files_in_dir = fileset(var.local_path, "**")
  content_hash = sha1(join("", [for f in local.files_in_dir : filesha256("${var.local_path}/${f}")]))

  host = (var.use_public_ip
    ? coalesce(data.aws_instance.target.public_ip, data.aws_instance.target.public_dns)
    : coalesce(data.aws_instance.target.private_ip, data.aws_instance.target.private_dns))

  app_dir              = basename(trim(var.local_path, "/"))
  effective_remote_dir = "${trimsuffix(var.remote_dir, "/")}/${local.app_dir}"
}

resource "null_resource" "deploy" {
  triggers = {
    instance_id = var.instance_id
    remote_dir  = var.remote_dir
    compose     = var.compose_file
    hash        = local.content_hash
    extra_nonce = var.force_redeploy_nonce
  }

  connection {
    type        = "ssh"
    host        = local.host
    user        = var.ssh_user
    private_key = var.ssh_private_key
    # se precisar de bastion, adicione aqui as chaves bastion_*
  }

  # 1) Preparação do diretório remoto
  provisioner "remote-exec" {
    inline = [
      "sudo bash -lc 'set -Eeuo pipefail; mkdir -p ${var.remote_dir}; chown ${var.ssh_user}:${var.ssh_user} ${var.remote_dir}'"
    ]
  }

  # 2) Copia a pasta local inteira para a instância
  provisioner "file" {
    source      = var.local_path
    destination = "${var.remote_dir}/"
  }


provisioner "remote-exec" {
  inline = [<<-EOF
      sudo bash -lc 'set -Eeuo pipefail;
      echo "[deploy] aguardando cloud-init...";
      for i in {1..300}; do cloud-init status 2>/dev/null | grep -qE "done|status: done" && break; sleep 2; done; cloud-init status || true;

      cd ${var.remote_dir};

      %{ if var.run_pull }
      docker compose -f ${local.effective_remote_dir}/${var.compose_file} pull;
      %{ endif }

      docker compose -f ${local.effective_remote_dir}/${var.compose_file} up -d --force-recreate;

      echo "[deploy] OK"'
    EOF
  ]
}

}
