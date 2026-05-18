output "registry_id" {
  description = "Yandex Container Registry ID"
  value       = yandex_container_registry.this.id
}

output "registry_endpoint" {
  description = "Docker registry endpoint (use as image prefix)"
  value       = "cr.yandex/${yandex_container_registry.this.id}"
}

output "pusher_sa_id" {
  description = "Service account ID for pushing images"
  value       = yandex_iam_service_account.pusher.id
}

output "pusher_key_id" {
  description = "Authorized key ID for docker login"
  value       = yandex_iam_service_account_key.pusher.id
}

output "pusher_key_private" {
  description = "Authorized key JSON for docker login (use as CI/CD variable)"
  value       = yandex_iam_service_account_key.pusher.private_key
  sensitive   = true
}
