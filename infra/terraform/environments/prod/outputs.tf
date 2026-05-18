# ──────────────────────────────────────────────────────────────────────────────
# Prod Environment – Outputs
# ──────────────────────────────────────────────────────────────────────────────

# ── VPC ──────────────────────────────────────────────────────────────────────
output "vpc_network_id" {
  description = "Prod VPC network ID"
  value       = module.vpc.network_id
}

output "private_subnet_ids" {
  description = "Prod private subnet IDs (zone → subnet_id)"
  value       = module.vpc.private_subnet_ids
}

# ── GitLab Runner ────────────────────────────────────────────────────────────
output "gitlab_runner_instance_ids" {
  description = "Prod GitLab runner instance IDs"
  value       = module.gitlab_runner.runner_instance_ids
}

output "gitlab_runner_internal_ips" {
  description = "Prod GitLab runner internal IPs"
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

# ── Static IPs ───────────────────────────────────────────────────────────────
output "nginx_external_ip" {
  description = "Static public IP for nginx-external LoadBalancer"
  value       = yandex_vpc_address.nginx_external.external_ipv4_address[0].address
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

# ── Loki Object Storage ──────────────────────────────────────────────────────
output "loki_s3_bucket_name" {
  description = "Loki S3 bucket name (use as loki_s3_bucket_name in Ansible)"
  value       = yandex_storage_bucket.loki.bucket
}

output "loki_s3_access_key" {
  description = "Loki S3 access key ID (store in Ansible Vault as vault_loki_s3_access_key)"
  value       = yandex_iam_service_account_static_access_key.loki.access_key
  sensitive   = true
}

output "loki_s3_secret_key" {
  description = "Loki S3 secret key (store in Ansible Vault as vault_loki_s3_secret_key)"
  value       = yandex_iam_service_account_static_access_key.loki.secret_key
  sensitive   = true
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

output "frontend_cdn_endpoint" {
  description = "Frontend CDN endpoint"
  value       = module.object_storage.cdn_endpoint
}
