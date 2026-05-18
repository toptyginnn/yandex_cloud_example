# ──────────────────────────────────────────────────────────────────────────────
# Temporal Module – Helm-based Temporal deployment in Kubernetes
# ──────────────────────────────────────────────────────────────────────────────

# ── Kubernetes Namespace ─────────────────────────────────────────────────────
resource "kubernetes_namespace" "temporal" {
  metadata {
    name = var.namespace
    labels = {
      app = "temporal"
      env = var.env_name
    }
  }
}

# ── Helm values (built dynamically based on mode) ───────────────────────────
locals {
  # Base values shared by stage and prod
  base_values = {
    server = {
      replicaCount = var.server_replica_count
    }

    web = {
      enabled      = var.web_enabled
      replicaCount = 1
    }

    admintools = {
      enabled = var.admintools_enabled
    }

    cassandra = {
      enabled = false
    }

    elasticsearch = {
      enabled = false
    }

    prometheus = {
      enabled = false
    }

    grafana = {
      enabled = false
    }

    # Embedded PostgreSQL for stage
    postgresql = {
      enabled = var.use_embedded_postgresql
    }
  }

  # External PG values for prod mode
  external_pg_values = var.use_embedded_postgresql ? {} : {
    server = {
      replicaCount = var.server_replica_count

      config = {
        persistence = {
          default = {
            driver = "sql"
            sql = {
              pluginName = "postgres"
              host       = var.external_pg_host
              port       = var.external_pg_port
              user       = var.external_pg_user
              password   = var.external_pg_password
              database   = var.external_pg_database
            }
          }
          visibility = {
            driver = "sql"
            sql = {
              pluginName = "postgres"
              host       = var.external_pg_host
              port       = var.external_pg_port
              user       = var.external_pg_user
              password   = var.external_pg_password
              database   = "${var.external_pg_database}_visibility"
            }
          }
        }
      }
    }
  }

  # Merge base + external PG overrides
  final_values = var.use_embedded_postgresql ? local.base_values : merge(local.base_values, local.external_pg_values)
}

# ── Helm Release ─────────────────────────────────────────────────────────────
resource "helm_release" "temporal" {
  name       = "temporal"
  namespace  = kubernetes_namespace.temporal.metadata[0].name
  repository = "https://go.temporal.io/helm-charts"
  chart      = "temporal"
  version    = var.helm_chart_version
  timeout    = 900

  values = [yamlencode(local.final_values)]
}
