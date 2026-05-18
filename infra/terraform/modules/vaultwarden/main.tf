terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Vaultwarden Module – Helm-based deployment in Kubernetes
# ──────────────────────────────────────────────────────────────────────────────

# ── Lockbox secret for admin token ───────────────────────────────────────────
resource "yandex_lockbox_secret" "vaultwarden_admin" {
  name        = "${var.env_name}-vaultwarden-admin-token"
  description = "Vaultwarden admin token for ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_lockbox_secret_version" "vaultwarden_admin" {
  secret_id = yandex_lockbox_secret.vaultwarden_admin.id

  entries {
    key        = "admin_token"
    text_value = var.admin_token
  }
}

# ── Kubernetes Namespace ─────────────────────────────────────────────────────
resource "kubernetes_namespace" "vaultwarden" {
  metadata {
    name = var.namespace
    labels = {
      app = "vaultwarden"
      env = var.env_name
    }
  }
}

# ── Helm Release ─────────────────────────────────────────────────────────────
resource "helm_release" "vaultwarden" {
  name       = "vaultwarden"
  namespace  = kubernetes_namespace.vaultwarden.metadata[0].name
  repository = "https://guerzon.github.io/vaultwarden"
  chart      = "vaultwarden"
  version    = var.helm_chart_version

  values = [
    yamlencode({
      domain = var.domain

      env = {
        DOMAIN            = var.domain
        SIGNUPS_ALLOWED   = "false"
        WEBSOCKET_ENABLED = "true"
        ADMIN_TOKEN       = var.admin_token
        DATABASE_URL      = var.database_url
        ROCKET_PORT       = 8080
      }

      persistence = {
        enabled      = true
        size         = var.pvc_size
        storageClass = var.storage_class
        accessMode   = "ReadWriteOnce"
        path         = "/data"
      }

      ingress = {
        enabled = true
        class   = "nginx"
        annotations = {
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
        }
        hosts = [
          {
            host = var.ingress_hostname
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }

      service = {
        type = "ClusterIP"
        port = 8080
      }
    })
  ]
}
