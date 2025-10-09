locals {
    fqdn = trim(var.sub_domain) != "" ? "${var.sub_domain}.${var.domain}" : var.domain
}

data "aws_subnet" "of_instance" {
    id = var.subnet_id
}

resource "aws_ebs_volume" "data" {
    availability_zone = data.aws_subnet.of_instance.availability_zone
    size              = 20
    type              = "gp3"
    encrypted         = true

    tags = {
        Name = "n8n for ${fqdn}"
    }
}

module "n8n" {
    name = "n8n"
    source = "git::https://github.com/malacration/ar-tofu-toolkit.git//modules/ec2-docker?ref=main"
    subnet_id = data.aws_subnet.of_instance.id
    associate_public_ip = true
    
    ssh_authorized_keys = var.ssh_authorized_keys
    ssh_ingress_cidrs = [
        "0.0.0.0/0"
    ]
    data_volume_existing_id = aws_ebs_volume.data.id
    data_volume_auto_format_mount = true
    create_data_volume = true
}

module "deploy-n8n" {
    source = "git::https://github.com/malacration/ar-tofu-toolkit.git//modules/deploy_compose?ref=main"
    instance_id = module.n8n.output.instanceID
    local_path = "./n8n"
    remote_dir = "/app"
    ssh_private_key = var.ssh_authorized_keys[0]
    template_vars = { domain = "${local.sub-domain}.${local.domain}" }
}

module "cloud-front-n8n" {
    source = "git::https://github.com/malacration/ar-tofu-toolkit.git//modules/cloud-front-to-public-ec2?ref=main"
    domain = local.domain
    sub-domain = local.sub-domain
    instance_id_ec2 = module.n8n.output.instanceID
    origin_protocol_policy = "http-only"
}

output "n8n-vm" {
  value = module.cloud-front-n8n.all
}