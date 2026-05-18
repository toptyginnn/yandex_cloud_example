# ──────────────────────────────────────────────────────────────────────────────
# Kubernetes Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = yandex_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = yandex_kubernetes_cluster.this.name
}

output "cluster_endpoint" {
  description = "Internal endpoint of the Kubernetes API server"
  value       = yandex_kubernetes_cluster.this.master[0].internal_v4_endpoint
}

output "cluster_ca_certificate" {
  description = "PEM-encoded CA certificate of the cluster"
  value       = yandex_kubernetes_cluster.this.master[0].cluster_ca_certificate
  sensitive   = true
}

output "node_group_id" {
  description = "ID of the worker node group"
  value       = yandex_kubernetes_node_group.workers.id
}

output "cluster_service_account_id" {
  description = "Service account ID used by the cluster"
  value       = yandex_iam_service_account.k8s_cluster.id
}

output "node_service_account_id" {
  description = "Service account ID used by the node group"
  value       = yandex_iam_service_account.k8s_node.id
}
