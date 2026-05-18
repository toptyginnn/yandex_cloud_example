terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Container Registry Module – Yandex Cloud private Docker registry
# ──────────────────────────────────────────────────────────────────────────────

resource "yandex_container_registry" "this" {
  name      = var.registry_name
  folder_id = var.folder_id
}

# ── Service Account for pushing images (GitLab CI) ───────────────────────────
resource "yandex_iam_service_account" "pusher" {
  name        = "${var.registry_name}-pusher"
  description = "Pushes images to ${var.registry_name} registry (used by GitLab CI)"
  folder_id   = var.folder_id
}

resource "yandex_container_registry_iam_binding" "pusher" {
  registry_id = yandex_container_registry.this.id
  role        = "container-registry.images.pusher"

  members = [
    "serviceAccount:${yandex_iam_service_account.pusher.id}",
  ]
}

resource "yandex_iam_service_account_key" "pusher" {
  service_account_id = yandex_iam_service_account.pusher.id
  description        = "Authorized key for docker login to ${var.registry_name}"
}
