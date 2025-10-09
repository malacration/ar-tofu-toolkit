terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_subnet" "da_instancia" {
  id = var.subnet_id
}

locals {
  # Detecta Graviton pelo sufixo 'g' (t4g.*, c7g.*, m7g.*, etc.)
  is_graviton  = can(regex("^[a-z]+\\d+g\\.", var.instance_type))
  derived_arch = var.ami_arch != null ? var.ami_arch : (local.is_graviton ? "arm64" : "x86_64")

  # Ubuntu 24.04 LTS via SSM (gp3)
  ssm_param = (local.derived_arch == "arm64"
    ? "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
    : "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id")

  creating_new = var.create_data_volume && var.data_volume_existing_id == null
  will_attach_data_volume  = var.data_volume_existing_id != null || local.creating_new


  # Corrige o ID para o caminho por-id (remove o hífen após 'vol-')
  data_volume_id_for_byid = local.will_attach_data_volume ? replace(var.data_volume_existing_id, "vol-", "vol") : null

  # Caminho estável do device (instâncias Nitro) por ID do volume
  data_device_by_id = local.will_attach_data_volume ? "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${local.data_volume_id_for_byid}" : null

  # --- SOMENTE write_files aqui, SEM runcmd (para não duplicar a chave) ---
  # Importante: inicie "write_files:" na coluna 0 e indente os '-' com dois espaços.
  cloud_init_data_volume = local.will_attach_data_volume ? (<<-YAML
write_files:
  - path: /usr/local/bin/attach-mount-data.sh
    permissions: '0755'
    content: |
      #!/usr/bin/env bash
      set -euo pipefail
      DEV_BY_ID="${local.data_device_by_id}"
      MNT="${var.data_volume_mount_path}"
      FSTYPE="${var.data_volume_fs}"
      LABEL="data"

      # aguarda o device aparecer (até 180s)
      timeout=180
      while [ $timeout -gt 0 ]; do
        [ -e "$DEV_BY_ID" ] && break
        /usr/bin/udevadm settle || true
        sleep 2
        timeout=$((timeout-2))
      done

      if [ ! -e "$DEV_BY_ID" ]; then
        echo "ERRO: device $DEV_BY_ID não apareceu" >&2
        exit 1
      fi

      # cria filesystem se o disco estiver cru
      if ! /usr/bin/lsblk -no FSTYPE "$DEV_BY_ID" | /usr/bin/grep -qE '(xfs|ext4|btrfs)'; then
        case "$FSTYPE" in
          xfs)   /sbin/mkfs.xfs   -L "$LABEL" "$DEV_BY_ID" ;;
          ext4)  /sbin/mkfs.ext4  -L "$LABEL" -F "$DEV_BY_ID" ;;
          btrfs) /sbin/mkfs.btrfs -L "$LABEL" -f "$DEV_BY_ID" ;;
          *) echo "FSTYPE $FSTYPE não suportado"; exit 2 ;;
        esac
      fi

      mkdir -p "$MNT"

      # fstab por UUID para ficar imune a renomeação de device
      UUID=$(/sbin/blkid -s UUID -o value "$DEV_BY_ID")
      if ! /bin/grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID $MNT $FSTYPE defaults,nofail,x-systemd.device-timeout=180 0 2" >> /etc/fstab
      fi

      /usr/bin/systemctl daemon-reload || true
      /bin/mount -a || /bin/mount "$MNT"
      OS_USER="${var.data_volume_owner_user}"
      OS_GROUP="${var.data_volume_owner_group}"
      DIR_MODE="${var.data_volume_dir_mode}"

      # cria grupo se não existir e adiciona o usuário
      getent group "$OS_GROUP" >/dev/null || groupadd "$OS_GROUP"
      usermod -aG "$OS_GROUP" "$OS_USER" || true

      # aplica ownership/permissões no diretório raiz do mount
      chown root:"$OS_GROUP" "$MNT"
      chmod "$DIR_MODE" "$MNT"

      # ACL default p/ que tudo novo herde rwx do grupo
      if command -v setfacl >/dev/null 2>&1; then
        setfacl -d -m g:"$OS_GROUP":rwx "$MNT" || true
      fi

      # Se o FS estiver vazio, pode ajustar tudo recursivamente sem medo:
      if [ -z "$(ls -A "$MNT")" ]; then
        chgrp -R "$OS_GROUP" "$MNT" || true
        chmod -R g+rwX "$MNT" || true
      fi

  - path: /etc/systemd/system/attach-mount-data.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Formatar (se preciso) e montar o EBS de dados
      Wants=network-online.target
      After=network-online.target
      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/attach-mount-data.sh
      RemainAfterExit=yes
      [Install]
      WantedBy=multi-user.target
YAML
) : ""

  # Cloud-init completo — AQUI vai o ÚNICO runcmd
cloud_init = <<-YAML
#cloud-config
package_update: true

apt:
  sources:
    docker:
      source: "deb https://download.docker.com/linux/ubuntu $RELEASE stable"
      # importa a chave direto do keyserver (fingerprint oficial do Docker)
      keyid: "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
      keyserver: "keyserver.ubuntu.com"

users:
  - name: ubuntu
    groups: [ sudo, docker ]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    ssh_authorized_keys:
    %{~ for k in var.ssh_authorized_keys ~}
      - ${k}
    %{~ endfor ~}

packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin
  - nvme-cli
  - xfsprogs
  - e2fsprogs
  - btrfs-progs
  - acl

${indent(0, local.cloud_init_data_volume)}

runcmd:
%{ if local.will_attach_data_volume ~}
  - [ bash, -lc, "systemctl daemon-reload" ]
  - [ bash, -lc, "systemctl enable attach-mount-data.service" ]
  - [ bash, -lc, "systemctl start attach-mount-data.service || true" ]
%{ endif ~}
  - [ bash, -lc, "systemctl enable --now docker" ]
  - [ bash, -lc, "usermod -aG docker ubuntu || true" ]
%{ if trimspace(var.user_data_extra) != "" ~}
  - [ bash, -lc, ${jsonencode(var.user_data_extra)} ]
%{ endif ~}
YAML
}

# Buscar AMI
data "aws_ssm_parameter" "ubuntu" {
  name = local.ssm_param
}

# SG básico
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = data.aws_subnet.vpc_id

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  dynamic "ingress" {
    for_each = var.ssh_ingress_cidrs
    content {
      description = "SSH"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = [ingress.value]
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

# EC2
resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name

  user_data                   = local.cloud_init
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(var.tags, { Name = var.name })
}

# Attachment (com validações)
resource "aws_volume_attachment" "data" {
  count             = local.creating_new ? 1 : 0
  device_name  = var.data_volume_device_name
  volume_id    = var.data_volume_existing_id
  instance_id  = aws_instance.this.id
  skip_destroy = false
}
