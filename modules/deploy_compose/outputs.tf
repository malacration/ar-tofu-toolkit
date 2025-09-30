output "output" {
  description = "Resultado do deploy via SSH"
  value = {
    instance_id = var.instance_id
    remote_dir  = var.remote_dir
    compose     = var.compose_file
    hash        = sha1(join("", [for f in fileset(var.local_path, "**") : filesha256("${var.local_path}/${f}")]))
  }
}
