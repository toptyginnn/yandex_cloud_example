# ──────────────────────────────────────────────────────────────────────────────
# GitLab Module – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "gitlab_public_ip" {
  description = "Static public IP address of the GitLab server"
  value       = try(yandex_vpc_address.gitlab[0].external_ipv4_address[0].address, null)
}

output "gitlab_instance_id" {
  description = "Compute instance ID of the GitLab server"
  value       = try(yandex_compute_instance.gitlab[0].id, null)
}

output "gitlab_internal_ip" {
  description = "Internal IP address of the GitLab server"
  value       = try(yandex_compute_instance.gitlab[0].network_interface[0].ip_address, null)
}

output "gitlab_fqdn" {
  description = "FQDN of the GitLab server"
  value       = try(yandex_compute_instance.gitlab[0].fqdn, null)
}

output "gitlab_external_url" {
  description = "GitLab external URL (use this in runner registration and CI/CD)"
  value       = var.gitlab_external_url
}

output "gitlab_data_disk_id" {
  description = "Separate data disk ID for GitLab persistent data"
  value       = try(yandex_compute_disk.gitlab_data[0].id, null)
}

output "gitlab_data_mount_path" {
  description = "Mount path for GitLab persistent data disk"
  value       = var.gitlab_data_mount_path
}

output "gitlab_backup_bt6_bucket_name" {
  description = "Object Storage bucket name for GitLab backups (null when disabled)"
  value       = try(yandex_storage_bucket.gitlab_backup_bt6[0].bucket, null)
}

output "gitlab_backup_bt6_storage_access_key" {
  description = "S3 access key for GitLab backup bucket (null when disabled)"
  value       = try(yandex_iam_service_account_static_access_key.gitlab_backup_bt6_storage[0].access_key, null)
  sensitive   = true
}

output "gitlab_backup_bt6_storage_secret_key" {
  description = "S3 secret key for GitLab backup bucket (null when disabled)"
  value       = try(yandex_iam_service_account_static_access_key.gitlab_backup_bt6_storage[0].secret_key, null)
  sensitive   = true
}

output "runner_instance_ids" {
  description = "List of compute instance IDs for GitLab runners"
  value       = yandex_compute_instance.runner[*].id
}

output "runner_internal_ips" {
  description = "List of internal IPs for GitLab runners"
  value       = yandex_compute_instance.runner[*].network_interface[0].ip_address
}
