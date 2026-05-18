terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# PostgreSQL Module – k8s (CloudNativePG operator) or managed (yandex_mdb)
# ──────────────────────────────────────────────────────────────────────────────

# ── Lockbox secret for DB password (both modes) ─────────────────────────────
resource "yandex_lockbox_secret" "pg_password" {
  name        = "${var.env_name}-pg-password"
  description = "PostgreSQL password for ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_lockbox_secret_version" "pg_password" {
  secret_id = yandex_lockbox_secret.pg_password.id

  entries {
    key        = "password"
    text_value = var.pg_password
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# MODE: k8s  –  CloudNativePG operator (CNCF, Apache 2.0 license)
# ═════════════════════════════════════════════════════════════════════════════

# Install the CloudNativePG operator via its official Helm chart
resource "helm_release" "cnpg_operator" {
  count = var.engine == "k8s" ? 1 : 0

  name             = "cnpg"
  namespace        = "cnpg-system"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = var.cnpg_operator_chart_version
  create_namespace = true

  values = [yamlencode({
    monitoring = {
      podMonitorEnabled = false
    }
  })]
}

# Create a Kubernetes secret with the PG superuser password
resource "kubernetes_secret" "pg_superuser" {
  count = var.engine == "k8s" ? 1 : 0

  metadata {
    name      = "${var.env_name}-pg-superuser"
    namespace = var.k8s_namespace
  }

  data = {
    username = var.pg_user
    password = var.pg_password
  }

  type = "kubernetes.io/basic-auth"
}

# Create the CloudNativePG Cluster custom resource via kubectl manifest
resource "kubernetes_manifest" "cnpg_cluster" {
  count = var.engine == "k8s" ? 1 : 0

  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = "${var.env_name}-pg"
      namespace = var.k8s_namespace
    }
    spec = {
      instances             = var.cnpg_instances
      imageName             = "ghcr.io/cloudnative-pg/postgresql:${var.pg_version}"
      primaryUpdateStrategy = "unsupervised"

      bootstrap = {
        initdb = {
          database = var.pg_database
          owner    = var.pg_user
          secret = {
            name = kubernetes_secret.pg_superuser[0].metadata[0].name
          }
        }
      }

      storage = {
        size         = var.pvc_size
        storageClass = var.storage_class
      }

      resources = {
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      postgresql = {
        parameters = {
          max_connections = "100"
          shared_buffers  = "128MB"
        }
      }
    }
  }

  depends_on = [helm_release.cnpg_operator]
}

# ═════════════════════════════════════════════════════════════════════════════
# MODE: managed  –  Yandex Managed PostgreSQL (MDB)
# ═════════════════════════════════════════════════════════════════════════════
resource "yandex_mdb_postgresql_cluster" "this" {
  count = var.engine == "managed" ? 1 : 0

  name        = "${var.env_name}-pg"
  description = "Managed PostgreSQL for ${var.env_name}"
  folder_id   = var.folder_id
  environment = var.env_name == "prod" ? "PRODUCTION" : "PRESTABLE"
  network_id  = var.network_id

  config {
    version = "16"

    resources {
      resource_preset_id = var.mdb_resource_preset
      disk_type_id       = "network-ssd"
      disk_size          = var.mdb_disk_size_gb
    }

    postgresql_config = {
      max_connections = 100
    }
  }

  dynamic "host" {
    for_each = var.mdb_host_zones
    content {
      zone             = host.value.zone
      subnet_id        = host.value.subnet_id
      assign_public_ip = false
    }
  }

  maintenance_window {
    type = "WEEKLY"
    day  = "SUN"
    hour = 3
  }
}

resource "yandex_mdb_postgresql_database" "this" {
  count      = var.engine == "managed" ? 1 : 0
  cluster_id = yandex_mdb_postgresql_cluster.this[0].id
  name       = var.pg_database
  owner      = var.pg_user

  depends_on = [yandex_mdb_postgresql_user.this]
}

resource "yandex_mdb_postgresql_user" "this" {
  count      = var.engine == "managed" ? 1 : 0
  cluster_id = yandex_mdb_postgresql_cluster.this[0].id
  name       = var.pg_user
  password   = var.pg_password

  permission {
    database_name = var.pg_database
  }
}
