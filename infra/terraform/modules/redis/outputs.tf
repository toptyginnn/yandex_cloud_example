# ──────────────────────────────────────────────────────────────────────────────
# Redis Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "lockbox_secret_id" {
  description = "Lockbox secret ID storing the Redis password"
  value       = yandex_lockbox_secret.redis_password.id
}

# ── k8s mode outputs ────────────────────────────────────────────────────────
output "k8s_deployment_name" {
  description = "Kubernetes Deployment name (k8s mode)"
  value       = var.engine == "k8s" ? kubernetes_deployment.redis[0].metadata[0].name : null
}

output "k8s_service_host" {
  description = "In-cluster Redis service hostname (k8s mode)"
  value       = var.engine == "k8s" ? "redis-master.${var.k8s_namespace}.svc.cluster.local" : null
}

output "k8s_service_port" {
  description = "Redis port (k8s mode)"
  value       = var.engine == "k8s" ? 6379 : null
}

# ── Managed mode outputs ────────────────────────────────────────────────────
output "mdb_cluster_id" {
  description = "MDB Redis cluster ID (managed mode)"
  value       = var.engine == "managed" ? yandex_mdb_redis_cluster.this[0].id : null
}

output "mdb_cluster_hosts" {
  description = "MDB Redis host FQDNs (managed mode)"
  value       = var.engine == "managed" ? yandex_mdb_redis_cluster.this[0].host[*].fqdn : []
}

# ── Universal outputs ───────────────────────────────────────────────────────
output "connection_host" {
  description = "Hostname to connect to Redis (works for both modes)"
  value = var.engine == "k8s" ? (
    "redis-master.${var.k8s_namespace}.svc.cluster.local"
    ) : (
    var.engine == "managed" ? yandex_mdb_redis_cluster.this[0].host[0].fqdn : ""
  )
}

output "connection_port" {
  description = "Port to connect to Redis"
  value       = 6379
}
