# ──────────────────────────────────────────────────────────────────────────────
# Vaultwarden Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "lockbox_secret_id" {
  description = "Lockbox secret ID storing the admin token"
  value       = yandex_lockbox_secret.vaultwarden_admin.id
}

output "namespace" {
  description = "Kubernetes namespace where Vaultwarden is deployed"
  value       = kubernetes_namespace.vaultwarden.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.vaultwarden.name
}

output "internal_url" {
  description = "Internal URL to access Vaultwarden"
  value       = "http://vaultwarden.${var.namespace}.svc.cluster.local:8080"
}

output "ingress_hostname" {
  description = "Ingress hostname for Vaultwarden"
  value       = var.ingress_hostname
}
