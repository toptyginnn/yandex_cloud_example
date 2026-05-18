terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Redis Module – k8s (raw Deployment with redis:7) or managed (yandex_mdb_redis)
# ──────────────────────────────────────────────────────────────────────────────

# ── Lockbox secret for Redis password ────────────────────────────────────────
resource "yandex_lockbox_secret" "redis_password" {
  name        = "${var.env_name}-redis-password"
  description = "Redis password for ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_lockbox_secret_version" "redis_password" {
  secret_id = yandex_lockbox_secret.redis_password.id

  entries {
    key        = "password"
    text_value = var.redis_password
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# MODE: k8s  –  Raw Kubernetes Deployment with official redis:7 image
# ═════════════════════════════════════════════════════════════════════════════

resource "kubernetes_namespace" "redis" {
  count = var.engine == "k8s" ? 1 : 0

  metadata {
    name = var.k8s_namespace
    labels = {
      app = "redis"
      env = var.env_name
    }
  }
}

resource "kubernetes_secret" "redis_password" {
  count = var.engine == "k8s" ? 1 : 0

  metadata {
    name      = "redis-password"
    namespace = kubernetes_namespace.redis[0].metadata[0].name
  }

  data = {
    REDIS_PASSWORD = var.redis_password
  }
}

resource "kubernetes_config_map" "redis" {
  count = var.engine == "k8s" ? 1 : 0

  metadata {
    name      = "redis-config"
    namespace = kubernetes_namespace.redis[0].metadata[0].name
  }

  data = {
    "redis.conf" = <<-EOT
      bind 0.0.0.0
      port 6379
      requirepass ${var.redis_password}
      maxmemory 200mb
      maxmemory-policy allkeys-lru
      appendonly no
      save ""
    EOT
  }
}

resource "kubernetes_deployment" "redis" {
  count = var.engine == "k8s" ? 1 : 0

  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.redis[0].metadata[0].name
    labels = {
      app = "redis"
      env = var.env_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
          env = var.env_name
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:${var.redis_version}"

          command = ["redis-server", "/etc/redis/redis.conf"]

          port {
            container_port = 6379
            name           = "redis"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "redis-config"
            mount_path = "/etc/redis"
            read_only  = true
          }

          liveness_probe {
            exec {
              command = ["redis-cli", "-a", "$(REDIS_PASSWORD)", "ping"]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["redis-cli", "-a", "$(REDIS_PASSWORD)", "ping"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.redis_password[0].metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }
        }

        volume {
          name = "redis-config"
          config_map {
            name = kubernetes_config_map.redis[0].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  count = var.engine == "k8s" ? 1 : 0

  metadata {
    name      = "redis-master"
    namespace = kubernetes_namespace.redis[0].metadata[0].name
    labels = {
      app = "redis"
    }
  }

  spec {
    selector = {
      app = "redis"
    }

    port {
      port        = 6379
      target_port = 6379
      name        = "redis"
    }

    type = "ClusterIP"
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# MODE: managed  –  Yandex Managed Redis (MDB)
# ═════════════════════════════════════════════════════════════════════════════
resource "yandex_mdb_redis_cluster" "this" {
  count = var.engine == "managed" ? 1 : 0

  name        = "${var.env_name}-redis"
  description = "Managed Redis for ${var.env_name}"
  folder_id   = var.folder_id
  environment = var.env_name == "prod" ? "PRODUCTION" : "PRESTABLE"
  network_id  = var.network_id
  sharded     = false

  config {
    version  = "7.0"
    password = var.redis_password

    maxmemory_policy = "allkeys-lru"
  }

  resources {
    resource_preset_id = var.mdb_resource_preset
    disk_type_id       = "network-ssd"
    disk_size          = var.mdb_disk_size_gb
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
    hour = 4
  }
}
