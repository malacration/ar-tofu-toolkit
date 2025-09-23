output "instance_id" {
  value       = aws_instance.this.id
  description = "ID da instância EC2"
}

output "private_ip" {
  value       = aws_instance.this.private_ip
  description = "IP privado da instância"
}

output "public_ip" {
  value       = aws_instance.this.public_ip
  description = "IP público (se associado)"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "ID do Security Group criado"
}

output "ami_id" {
  value       = aws_instance.this.ami
  description = "AMI usada"
}

output "data_volume_id" {
  description = "ID do volume de dados anexado (existente ou criado)"
  value       = local.data_volume_id
}

output "created_data_volume_id" {
  description = "ID do volume criado pelo módulo (null se foi usado um existente ou se attach=false)"
  value       = local.create_data_volume ? aws_ebs_volume.data[0].id : null
}