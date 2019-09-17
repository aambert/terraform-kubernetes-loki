resource "kubernetes_namespace" "loki" {
  count = var.loki_namespace_create ? 1 : 0
  metadata {
    name = var.loki_namespace
  }
}

resource "kubernetes_service_account" "loki" {
  metadata {
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "loki"
    }
    name      = "loki"
    namespace = var.loki_namespace
  }
}

resource "kubernetes_role" "loki" {
  metadata {
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "loki"
    }
    name      = "loki"
    namespace = var.loki_namespace
  }
  rule {
    api_groups     = ["extensions"]
    resources      = ["podsecuritypolicies"]
    verbs          = ["use"]
    resource_names = ["loki"]
  }
}

resource "kubernetes_role_binding" "loki" {
  metadata {
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "loki"
    }
    name      = "loki"
    namespace = var.loki_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.loki.metadata[0].name
  }
  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.loki.metadata[0].name
  }
}

resource "kubernetes_service" "loki" {
  metadata {
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "loki"
    }
    name      = "loki"
    namespace = var.loki_namespace
  }
  spec {
    port {
      name        = "grpc-api"
      port        = 9095
      protocol    = "TCP"
      target_port = "grpc"
    }
    port {
      name        = "http-metrics"
      port        = 3100
      protocol    = "TCP"
      target_port = "metrics"
    }
    selector = {
      "app.kubernetes.io/name" = "loki"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_secret" "loki_config" {
  metadata {
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "loki"
    }
    name      = "loki-config"
    namespace = var.loki_namespace
  }
  data = {
    "loki.yaml" = base64encode(templatefile("${path.module}/templates/loki.yaml", {}))
  }
}

resource "kubernetes_stateful_set" "loki" {
  metadata {
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "loki"
      "app.kubernetes.io/version"    = "${var.loki_version}"
    }
    name      = "loki"
    namespace = var.loki_namespace
  }
  spec {
    pod_management_policy = "Parallel"
    revision_history_limit = 3
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"       = "loki"
      }
    }
    service_name = "loki"
    update_strategy {
      type = "RollingUpdate"
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/managed-by" = "terraform"
          "app.kubernetes.io/name"       = "loki"
         "app.kubernetes.io/version" = "${var.loki_version}"
        }
      }
      spec {
        node_selector = {}
        service_account_name = kubernetes_service_account.loki.metadata[0].name
        security_context {
          fs_group = 10001
          run_as_group = 10001
          run_as_non_root = true
          run_as_user = 10001
        }
        container {
          name = "loki"
          image = "grafana/loki:v${var.loki_version}"
          image_pull_policy = "IfNotPresent"
          args = [
            "-config.file=/etc/loki/loki.yaml"
          ]
          volume_mount {
            name = "config"
            mount_path = "/etc/loki"
            read_only = true
          }
          volume_mount {
            name = "loki-data"
            mount_path = "/data"
            read_only = false
          }
          port {
            name = "metrics"
            container_port = 3100
            protocol = "TCP"
          }
          port {
            name = "grpc"
            container_port = 9095
            protocol = "TCP"
          }
          liveness_probe {
            http_get {
              path = "/ready"
              port = "metrics"
            }
            initial_delay_seconds = 45
          }
          readiness_probe {
            http_get {
              path = "/ready"
              port = "metrics"
            }
            initial_delay_seconds = 45
          }
          resources {}
          security_context {
            read_only_root_filesystem = true
          }
        }
        termination_grace_period_seconds = 30
        volume {
          name = "config"
          secret {
            secret_name = kubernetes_secret.loki_config.metadata[0].name
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "loki-data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = var.loki_volume_claim_template_storage_request
          }
        }
        storage_class_name = var.loki_volume_claim_template_storage_class_name
      }
    }
  }
}
