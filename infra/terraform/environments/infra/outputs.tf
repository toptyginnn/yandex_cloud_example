# ──────────────────────────────────────────────────────────────────────────────
# Infra Environment – Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "vpc_network_id" {
  description = "Infra VPC network ID"
  value       = module.vpc.network_id
}

output "vpn_public_ip" {
  description = "NetBird VPN public IP"
  value       = module.vpn.vpn_public_ip
}

output "vpn_internal_ip" {
  description = "VPN server internal IP"
  value       = module.vpn.vpn_internal_ip
}

output "gitlab_internal_ip" {
  description = "GitLab server internal IP (access via VPN)"
  value       = module.gitlab.gitlab_internal_ip
}

output "gitlab_public_ip" {
  description = "GitLab server public static IP"
  value       = module.gitlab.gitlab_public_ip
}

output "gitlab_fqdn" {
  description = "GitLab server FQDN"
  value       = module.gitlab.gitlab_fqdn
}

output "gitlab_external_url" {
  description = "GitLab external URL"
  value       = module.gitlab.gitlab_external_url
}

output "gitlab_data_disk_id" {
  description = "GitLab separate data disk ID"
  value       = module.gitlab.gitlab_data_disk_id
}

output "gitlab_data_mount_path" {
  description = "GitLab data disk mount path"
  value       = module.gitlab.gitlab_data_mount_path
}

output "gitlab_backup_bt6_bucket_name" {
  description = "Object Storage bucket name for GitLab backups"
  value       = module.gitlab.gitlab_backup_bt6_bucket_name
}

output "gitlab_backup_bt6_storage_access_key" {
  description = "S3 access key for GitLab backup bucket"
  value       = module.gitlab.gitlab_backup_bt6_storage_access_key
  sensitive   = true
}

output "gitlab_backup_bt6_storage_secret_key" {
  description = "S3 secret key for GitLab backup bucket"
  value       = module.gitlab.gitlab_backup_bt6_storage_secret_key
  sensitive   = true
}

# ── Mailcow ──────────────────────────────────────────────────────────────────
output "mailcow_public_ip" {
  description = "Mailcow server static public IP (set A/MX/PTR DNS records to this)"
  value       = module.mailcow.mailcow_public_ip
}

output "mailcow_internal_ip" {
  description = "Mailcow server internal IP (access via VPN)"
  value       = module.mailcow.mailcow_internal_ip
}

output "mailcow_data_disk_id" {
  description = "Mailcow data disk ID"
  value       = module.mailcow.mailcow_data_disk_id
}

# ── Container Registry ───────────────────────────────────────────────────────
output "registry_id" {
  description = "Yandex Container Registry ID"
  value       = module.container_registry.registry_id
}

output "registry_endpoint" {
  description = "Docker image prefix (cr.yandex/<id>)"
  value       = module.container_registry.registry_endpoint
}

output "registry_pusher_key" {
  description = "Authorized key JSON for docker login (set as CI_REGISTRY_PASSWORD in GitLab)"
  value       = module.container_registry.pusher_key_private
  sensitive   = true
}
