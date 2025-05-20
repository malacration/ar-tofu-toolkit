# Recurso para verificar a mudança na versão do release
resource "null_resource" "check_release_version" {
  triggers = {
    release_version = var.release_version
  }

  provisioner "local-exec" {
    command = "echo Release version changed to ${var.release_version}"
  }
}


data "external" "download_release" {
  program = [
    "${path.module}/scripts/download_release.sh",
    var.release_version,
    var.repo_owner,
    var.repo_name,
    var.github_token,
    "${abspath(path.root)}/${local.full_name}",
    var.path_adicional != null ? var.path_adicional : ""
  ]
}


locals {
  content_type = {
    "html"   = "text/html",
    "css"    = "text/css",
    "js"     = "application/javascript",
    "png"    = "image/png",
    "jpg"    = "image/jpeg",
    "jpeg"   = "image/jpeg",
    "svg"    = "image/svg+xml",
    "woff"   = "font/woff",
    "woff2"  = "font/woff2",
    "eot"    = "application/vnd.ms-fontobject",
    "ttf"    = "font/ttf",
    "bmp"    = "image/bmp",
    "ico"    = "image/x-icon"
  }
  
  distPath = var.release_version == "none" ? "${abspath(path.root)}/${local.full_name}/dist" : "${abspath(path.root)}/${local.full_name}/dist/dist-${var.release_version}"
}

resource "aws_s3_object" "files" {
  for_each = fileset("${local.distPath}", "**")

  bucket = aws_s3_bucket.bucket.bucket
  key    = each.value
  source = "${local.distPath}/${each.value}"
  etag   = filemd5("${local.distPath}/${each.value}")

  content_type = lookup(local.content_type, element(reverse(split(".", each.value)), 0), "application/octet-stream")

  depends_on = [null_resource.check_release_version]
}

resource "aws_s3_object" "adicional_files" {
  for_each = var.path_adicional != "" ? fileset("${abspath(path.root)}/${var.path_adicional}", "**") : []

  bucket = aws_s3_bucket.bucket.bucket
  key    = each.value
  source = "${path.module}/../../${var.path_adicional}/${each.value}"
  etag   = filemd5("${path.module}/../../${var.path_adicional}/${each.value}")

  content_type = lookup(local.content_type, element(reverse(split(".", each.value)), 0), "application/octet-stream")

  depends_on = [aws_s3_object.files]
}