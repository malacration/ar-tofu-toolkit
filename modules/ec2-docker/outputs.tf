output "output" {
  description = "Informações da EC2 e do volume de dados"
  value = {
    instanceID  = aws_instance.this.id
    public_ip   = aws_instance.this.public_ip
    private_ip  = aws_instance.this.private_ip
    volume_path = local.data_device_by_id   # null se não houver volume anexado
    subnet_id   = aws_instance.this.subnet_id
  }
}