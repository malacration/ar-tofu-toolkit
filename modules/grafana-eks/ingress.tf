resource "kubernetes_ingress_v1" "this" {
  count = var.ingress.enabled ? 1 : 0

  metadata {
    name      = var.helm_release_name
    namespace = var.namespace

    annotations = merge(
      {
        "alb.ingress.kubernetes.io/scheme"                              = var.ingress.scheme
        "alb.ingress.kubernetes.io/target-type"                         = var.ingress.target_type
        "alb.ingress.kubernetes.io/listen-ports"                        = var.ingress.listen_ports
        "alb.ingress.kubernetes.io/manage-backend-security-group-rules" = "false"
      },
      var.ingress.group_name != null ? { "alb.ingress.kubernetes.io/group.name" = var.ingress.group_name } : {},
      var.ingress.annotations
    )
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.ingress.host

      http {
        path {
          path      = var.ingress.path
          path_type = "Prefix"
          backend {
            service {
              name = helm_release.grafana.name
              port {
                number = var.service.port
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["field.cattle.io/publicEndpoints"],
    ]
  }

  depends_on = [helm_release.grafana]
}