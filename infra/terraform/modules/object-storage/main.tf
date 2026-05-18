terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Object Storage Module – S3 bucket for React SPA + CDN
# ──────────────────────────────────────────────────────────────────────────────

# ── Service Account for bucket management ────────────────────────────────────
resource "yandex_iam_service_account" "storage" {
  name        = "${var.env_name}-storage-sa"
  description = "Service account for Object Storage in ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.storage.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage" {
  service_account_id = yandex_iam_service_account.storage.id
  description        = "Static access key for ${var.env_name} storage bucket"
}

# ── Website Bucket ───────────────────────────────────────────────────────────
resource "yandex_storage_bucket" "frontend" {
  bucket     = var.bucket_name
  folder_id  = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage.secret_key

  acl = "public-read"

  website {
    index_document = "index.html"
    error_document = "index.html" # SPA fallback
  }

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = var.versioning_enabled
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.storage_admin
  ]
}

# ── CDN Resource ─────────────────────────────────────────────────────────────
resource "yandex_cdn_resource" "frontend" {
  count = var.cdn_enabled ? 1 : 0

  cname               = var.cdn_cname
  folder_id           = var.folder_id
  active              = true
  secondary_hostnames = var.cdn_secondary_hostnames

  origin_protocol = "https"

  origin_group_id = yandex_cdn_origin_group.frontend[0].id

  options {
    edge_cache_settings    = var.cdn_edge_cache_ttl
    browser_cache_settings = var.cdn_browser_cache_ttl
    cache_http_headers     = ["content-type", "content-length", "etag"]

    custom_host_header = "${var.bucket_name}.website.yandexcloud.net"
  }

  ssl_certificate {
    type = "not_used"
  }
}

resource "yandex_cdn_origin_group" "frontend" {
  count = var.cdn_enabled ? 1 : 0

  name      = "${var.env_name}-frontend-origins"
  folder_id = var.folder_id

  origin {
    source = "${var.bucket_name}.website.yandexcloud.net"
  }
}

# ── TLS Certificate (Certificate Manager) ───────────────────────────────────
resource "yandex_cm_certificate" "frontend" {
  count = var.tls_certificate_domain != "" ? 1 : 0

  name        = "${var.env_name}-frontend-cert"
  description = "TLS certificate for ${var.env_name} frontend"
  folder_id   = var.folder_id
  domains     = [var.tls_certificate_domain]

  managed {
    challenge_type = "DNS_CNAME"
  }
}
