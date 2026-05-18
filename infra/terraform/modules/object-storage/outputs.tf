# ──────────────────────────────────────────────────────────────────────────────
# Object Storage Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = yandex_storage_bucket.frontend.bucket
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = yandex_storage_bucket.frontend.bucket_domain_name
}

output "website_endpoint" {
  description = "Website endpoint URL of the bucket"
  value       = yandex_storage_bucket.frontend.website_endpoint
}

output "cdn_endpoint" {
  description = "CDN endpoint URL (empty if CDN disabled)"
  value       = var.cdn_enabled ? yandex_cdn_resource.frontend[0].cname : ""
}

output "storage_access_key" {
  description = "Static access key for the storage service account"
  value       = yandex_iam_service_account_static_access_key.storage.access_key
  sensitive   = true
}

output "storage_secret_key" {
  description = "Static secret key for the storage service account"
  value       = yandex_iam_service_account_static_access_key.storage.secret_key
  sensitive   = true
}

output "service_account_id" {
  description = "Service account ID for storage management"
  value       = yandex_iam_service_account.storage.id
}

output "certificate_id" {
  description = "Certificate Manager certificate ID (empty if not created)"
  value       = var.tls_certificate_domain != "" ? yandex_cm_certificate.frontend[0].id : ""
}
