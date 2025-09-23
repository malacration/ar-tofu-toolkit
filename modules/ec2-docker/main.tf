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
  is_graviton = can(regex("^[a-z]+\\d+g\\.", var.instance_type))
  derived_arch = var.ami_arch != null ? var.ami_arch : (local.is_graviton ? "arm64" : "x86_64")

  ssm_param = local.derived_arch == "arm64" ? "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id" : "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"

  # Cloud-init: injeta chaves + instala Docker + executa extras
  cloud_init = <<-EOT
    #cloud-config
    users:
      - name: ec2-user
        groups: [ wheel, docker ]
        sudo: ["ALL=(ALL) NOPASSWD:ALL"]
        shell: /bin/bash
        ssh_authorized_keys:
    %{~ for k in var.ssh_authorized_keys ~}
          - ${k}
    %{~ endfor ~}

    packages:
      - docker
      - docker-compose-plugin

    runcmd:
      - [ bash, -lc, "systemctl enable --now docker" ]
      - [ bash, -lc, "usermod -aG docker ec2-user || true" ]
    %{ if trimspace(var.user_data_extra) != "" ~}
      - [ bash, -lc, ${jsonencode(var.user_data_extra)} ]
    %{ endif ~}
  EOT

  will_attach_data_volume = var.attach_data_volume

  # cria volume só quando precisa e não foi passado um existente
  create_data_volume = local.will_attach_data_volume && var.data_volume_existing_id == null

  # YAML condicional para format/mount
  cloud_init_data_volume = var.data_volume_auto_format_mount && local.will_attach_data_volume ? <<-YAML
    disk_setup:
      ${var.data_volume_device_name}:
        table_type: gpt
        layout: true
        overwrite: false

    fs_setup:
      - label: data
        filesystem: ${var.data_volume_fs}
        device: ${var.data_volume_device_name}
        overwrite: false

    mounts:
      - [ "/dev/disk/by-label/data", "${var.data_volume_mount_path}", "${var.data_volume_fs}", "defaults,nofail", "0", "2" ]
  YAML 
    : ""

  data_volume_id = var.data_volume_existing_id != null ? var.data_volume_existing_id : (
    local.create_data_volume ? aws_ebs_volume.data[0].id : null
  )

}

data "aws_ssm_parameter" "al2023" {
  name = local.ssm_param
}

resource "aws_ebs_volume" "data" {
  count             = local.create_data_volume ? 1 : 0
  availability_zone = aws_instance.this.availability_zone
  size              = var.data_volume_size_gb
  type              = var.data_volume_type

  # Aplica IOPS/throughput só quando fizer sentido (gp3/io1/io2)
  iops       = contains(["gp3", "io1", "io2"], var.data_volume_type) ? var.data_volume_iops : null
  throughput = var.data_volume_type == "gp3" ? var.data_volume_throughput : null

  tags = merge(var.tags, { Name = "${var.name}-data" })
}

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

# Anexa o volume (quando habilitado)
resource "aws_volume_attachment" "data" {
  count       = local.will_attach_data_volume ? 1 : 0
  device_name = var.data_volume_device_name
  volume_id   = local.data_volume_id
  instance_id = aws_instance.this.id

  # Em geral deixe false (se true, impede destroy automático)
  skip_destroy = false
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name

  # cloud-init com chaves + docker
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
