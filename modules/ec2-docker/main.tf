terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Detecta Graviton pelo sufixo 'g' (t4g.*, c7g.*, m7g.*, etc.)
  is_graviton  = can(regex("^[a-z]+\\d+g\\.", var.instance_type))
  derived_arch = var.ami_arch != null ? var.ami_arch : (local.is_graviton ? "arm64" : "x86_64")

  # Ubuntu 24.04 LTS via SSM (gp3)
  ssm_param = (local.derived_arch == "arm64"
    ? "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
    : "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id")

  # Vamos anexar/formatar/montar SOMENTE se recebermos um volume_id
  will_attach_data_volume = var.data_volume_existing_id != null

  # Caminho estável do device (instâncias Nitro) por ID do volume
  data_device_by_id = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${var.data_volume_existing_id}"

  # YAML condicional para format/mount (quando houver volume). Use parênteses no heredoc!
  cloud_init_data_volume = local.will_attach_data_volume ? (
    var.data_volume_auto_format_mount ? <<-YAML
      disk_setup:
        ${local.data_device_by_id}:
          table_type: gpt
          layout: true
          overwrite: false

      fs_setup:
        - label: data
          filesystem: ${var.data_volume_fs}
          device: ${local.data_device_by_id}
          overwrite: false

      mounts:
        - [ "/dev/disk/by-label/data", "${var.data_volume_mount_path}", "${var.data_volume_fs}", "defaults,nofail", "0", "2" ]
    YAML
    :
    <<-YAML
      mounts:
        - [ "${local.data_device_by_id}", "${var.data_volume_mount_path}", "auto", "defaults,nofail", "0", "2" ]
    YAML
  ) : ""

  # Cloud-init completo
  cloud_init = <<-EOT
    #cloud-config
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
      - docker.io
      - docker-compose-plugin

    ${local.cloud_init_data_volume}

    runcmd:
      - [ bash, -lc, "systemctl enable --now docker" ]
      - [ bash, -lc, "usermod -aG docker ubuntu || true" ]
      %{ if trimspace(var.user_data_extra) != "" ~}
      - [ bash, -lc, ${jsonencode(var.user_data_extra)} ]
      %{ endif ~}
      # garante montagem mesmo se fs_setup/mounts falharem por timing
      - [ bash, -lc, "mkdir -p ${var.data_volume_mount_path} && mount -a || true" ]
      - [ bash, -lc, 'DEV="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${var.data_volume_existing_id}";
          test -e "$DEV" || DEV="/dev/nvme1n1";
          if ! lsblk -no FSTYPE "$DEV" | grep -qE "(xfs|ext4)"; then
            mkfs.xfs -L data "$DEV";
          fi;
          mkdir -p ${var.data_volume_mount_path};
          UUID=$(blkid -s UUID -o value "$DEV");
          if ! grep -q "$UUID" /etc/fstab; then
            echo "UUID=$UUID ${var.data_volume_mount_path} xfs defaults,nofail 0 2" >> /etc/fstab;
          fi;
          mount -a || true' ]
  EOT
}

# Buscar AMI
data "aws_ssm_parameter" "ubuntu" {
  name = local.ssm_param
}

# SG básico
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-sg-"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

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

# Attachment SEM count/for_each: sempre 1, com precondition exigindo o ID
resource "aws_volume_attachment" "data" {
  device_name  = var.data_volume_device_name
  volume_id    = var.data_volume_existing_id
  instance_id  = aws_instance.this.id
  skip_destroy = false

  lifecycle {
    precondition {
      condition     = var.data_volume_existing_id != null
      error_message = "Para criar o attachment, 'data_volume_existing_id' não pode ser null."
    }
  }
}
