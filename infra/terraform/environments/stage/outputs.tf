# ──────────────────────────────────────────────────────────────────────────────
# Stage Environment – Outputs
# ──────────────────────────────────────────────────────────────────────────────

# ── VPC ──────────────────────────────────────────────────────────────────────
output "vpc_network_id" {
  description = "Stage VPC network ID"
  value       = module.vpc.network_id
}

output "private_subnet_ids" {
  description = "Stage private subnet IDs (zone → subnet_id)"
  value       = module.vpc.private_subnet_ids
}

# ── GitLab Runner ────────────────────────────────────────────────────────────
output "gitlab_runner_instance_ids" {
  description = "Stage GitLab runner instance IDs"
  value       = module.gitlab_runner.runner_instance_ids
}

output "gitlab_runner_internal_ips" {
  description = "Stage GitLab runner internal IPs"
  value       = module.gitlab_runner.runner_internal_ips
}

# ── Kubernetes ───────────────────────────────────────────────────────────────
output "k8s_cluster_id" {
  description = "K8s cluster ID (use with: yc managed-kubernetes cluster get-credentials --id <id> --internal)"
  value       = module.k8s.cluster_id
}

output "k8s_cluster_endpoint" {
  description = "K8s API server internal endpoint"
  value       = module.k8s.cluster_endpoint
}

output "k8s_cluster_ca_certificate" {
  description = "PEM-encoded CA certificate of the K8s cluster"
  value       = module.k8s.cluster_ca_certificate
  sensitive   = true
}

# ── HashiCorp Vault KMS ───────────────────────────────────────────────────────
output "vault_kms_key_id" {
  description = "KMS key ID for HashiCorp Vault auto-unseal (use in Ansible group_vars)"
  value       = yandex_kms_symmetric_key.vault.id
}

output "vault_sa_authorized_key" {
  description = "Authorized key JSON for Vault service account (store in Ansible Vault as vault_hashicorp_vault_kms_auth_json)"
  sensitive   = true
  value = jsonencode({
    id                 = yandex_iam_service_account_key.vault.id
    service_account_id = yandex_iam_service_account.vault.id
    created_at         = yandex_iam_service_account_key.vault.created_at
    key_algorithm      = yandex_iam_service_account_key.vault.key_algorithm
    public_key         = yandex_iam_service_account_key.vault.public_key
    private_key        = yandex_iam_service_account_key.vault.private_key
  })
}

# ── Object Storage ───────────────────────────────────────────────────────────
output "frontend_bucket_name" {
  description = "Frontend S3 bucket name"
  value       = module.object_storage.bucket_name
}

output "frontend_website_endpoint" {
  description = "Frontend website endpoint"
  value       = module.object_storage.website_endpoint
}
