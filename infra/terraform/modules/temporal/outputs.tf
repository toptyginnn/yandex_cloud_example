# ──────────────────────────────────────────────────────────────────────────────
# Temporal Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "namespace" {
  description = "Kubernetes namespace where Temporal is deployed"
  value       = kubernetes_namespace.temporal.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.temporal.name
}

output "frontend_service_address" {
  description = "Temporal frontend gRPC service address for app workers"
  value       = "temporal-frontend.${var.namespace}.svc.cluster.local:7233"
}

output "web_ui_address" {
  description = "Temporal Web UI address (in-cluster)"
  value       = var.web_enabled ? "temporal-web.${var.namespace}.svc.cluster.local:8080" : ""
}
