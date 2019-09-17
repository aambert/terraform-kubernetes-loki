output "loki_namespace" {
  description = "Namespace into which Loki has been deployed."
  value = var.loki_namespace_create ? kubernetes_namespace.loki[0].metadata[0].name : var.loki_namespace
}
