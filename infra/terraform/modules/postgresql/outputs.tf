# ──────────────────────────────────────────────────────────────────────────────
# PostgreSQL Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "lockbox_secret_id" {
  description = "Lockbox secret ID storing the PG password"
  value       = yandex_lockbox_secret.pg_password.id
}

# ── k8s mode outputs (CloudNativePG) ────────────────────────────────────────
output "k8s_cluster_name" {
  description = "CloudNativePG Cluster resource name (k8s mode)"
  value       = var.engine == "k8s" ? "${var.env_name}-pg" : null
}

output "k8s_service_host" {
  description = "In-cluster PostgreSQL service hostname (k8s mode, read-write)"
  value       = var.engine == "k8s" ? "${var.env_name}-pg-rw.${var.k8s_namespace}.svc.cluster.local" : null
}

output "k8s_service_port" {
  description = "PostgreSQL port (k8s mode)"
  value       = var.engine == "k8s" ? 5432 : null
}

# ── Managed mode outputs ────────────────────────────────────────────────────
output "mdb_cluster_id" {
  description = "MDB PostgreSQL cluster ID (managed mode)"
  value       = var.engine == "managed" ? yandex_mdb_postgresql_cluster.this[0].id : null
}

output "mdb_cluster_hosts" {
  description = "MDB PostgreSQL host FQDNs (managed mode)"
  value       = var.engine == "managed" ? yandex_mdb_postgresql_cluster.this[0].host[*].fqdn : []
}

# ── Universal outputs ───────────────────────────────────────────────────────
output "pg_database" {
  description = "Database name"
  value       = var.pg_database
}

output "pg_user" {
  description = "Database username"
  value       = var.pg_user
}

output "connection_host" {
  description = "Hostname to connect to PostgreSQL (works for both modes)"
  value = var.engine == "k8s" ? (
    "${var.env_name}-pg-rw.${var.k8s_namespace}.svc.cluster.local"
    ) : (
    var.engine == "managed" ? yandex_mdb_postgresql_cluster.this[0].host[0].fqdn : ""
  )
}
