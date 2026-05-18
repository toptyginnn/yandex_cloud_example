# ──────────────────────────────────────────────────────────────────────────────
# Prod Environment – Module Wiring
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "tfstate-bt6-infra"
    key    = "prod/terraform.tfstate"
    region = "ru-central1"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = "ru-central1-a"
}

# ═════════════════════════════════════════════════════════════════════════════
# VPC – prod-vpc (multi-zone)
# ═════════════════════════════════════════════════════════════════════════════
module "vpc" {
  source = "../../modules/vpc"

  folder_id  = var.yc_folder_id
  env_name   = "prod"
  create_vpc = false
  network_id = "enpvduk371cj2jfnt683"  # infra-vpc (shared with stage)

  public_subnets = {
    "ru-central1-a" = "10.30.1.0/24"
    "ru-central1-b" = "10.30.3.0/24"
  }

  private_subnets = {
    "ru-central1-a" = "10.30.2.0/24"
    "ru-central1-b" = "10.30.4.0/24"
  }

  vpn_cidrs = var.vpn_cidrs

  additional_allowed_cidrs = [
    "10.20.1.23/32",
    "10.20.1.22/32",
    "10.113.0.0/16", # K8s pod CIDR prod (Calico BGP routing)
    "10.97.0.0/16",  # K8s service CIDR prod
  ]
}

# ═════════════════════════════════════════════════════════════════════════════
# GitLab Runner – prod only (GitLab server is in infra)
# ═════════════════════════════════════════════════════════════════════════════
module "gitlab_runner" {
  source = "../../modules/gitlab"

  folder_id = var.yc_folder_id
  env_name  = "prod"
  zone      = "ru-central1-a"

  create_gitlab_server = false
  create_runners       = true
  runner_count         = 1

  runner_subnet_id = module.vpc.private_subnet_ids["ru-central1-a"]
  runner_security_group_ids = [
    module.vpc.sg_allow_internal_id,
    module.vpc.sg_allow_ssh_id,
  ]

  ubuntu_image_id           = var.ubuntu_image_id
  ssh_public_keys           = var.ssh_public_keys
  gitlab_external_url       = var.gitlab_external_url
  runner_registration_token = var.runner_registration_token
  runner_tag_list           = var.runner_tag_list
}

# ═════════════════════════════════════════════════════════════════════════════
# Kubernetes – prod cluster (zonal master, multi-zone nodes, autoscaling)
# ═════════════════════════════════════════════════════════════════════════════
module "k8s" {
  source = "../../modules/k8s"

  folder_id  = var.yc_folder_id
  env_name   = "prod"
  network_id = module.vpc.network_id

  master_zones      = ["ru-central1-a"]
  master_subnet_ids = module.vpc.private_subnet_ids

  master_security_group_ids = [
    module.vpc.sg_allow_internal_id,
    module.vpc.sg_allow_k8s_api_id,
  ]

  node_zones      = ["ru-central1-a"]
  node_subnet_ids = module.vpc.private_subnet_ids

  node_security_group_ids = [
    module.vpc.sg_allow_internal_id,
    module.vpc.sg_allow_nlb_healthchecks_id,
  ]

  node_cores          = 4
  node_core_fraction  = 100
  node_memory_gb      = 16
  node_disk_size_gb   = 96
  node_preemptible    = false
  node_auto_scaling   = true
  node_auto_scale_min = 2
  node_auto_scale_max = 5

  cluster_ipv4_range = "10.113.0.0/16"
  service_ipv4_range = "10.97.0.0/16"

  ssh_public_keys = var.ssh_public_keys
}

# ═════════════════════════════════════════════════════════════════════════════
# Static IP for nginx-external LoadBalancer
# ═════════════════════════════════════════════════════════════════════════════
resource "yandex_vpc_address" "nginx_external" {
  name      = "prod-nginx-external"
  folder_id = var.yc_folder_id

  external_ipv4_address {
    zone_id = "ru-central1-b"
  }
}

# ═════════════════════════════════════════════════════════════════════════════
# Private DNS – *.internal
# ═════════════════════════════════════════════════════════════════════════════
resource "yandex_dns_zone" "internal" {
  name             = "prod-internal"
  zone             = "internal."
  folder_id        = var.yc_folder_id
  description      = "Private DNS zone for internal services (prod)"
  private_networks = [module.vpc.network_id]
}

resource "yandex_dns_recordset" "vault_internal" {
  count   = var.nginx_internal_lb_ip != "" ? 1 : 0
  zone_id = yandex_dns_zone.internal.id
  name    = "vault-prod.internal."
  type    = "A"
  ttl     = 60
  data    = [var.nginx_internal_lb_ip]
}

resource "yandex_dns_recordset" "hcvault_internal" {
  count   = var.nginx_internal_lb_ip != "" ? 1 : 0
  zone_id = yandex_dns_zone.internal.id
  name    = "hcvault.internal."
  type    = "A"
  ttl     = 60
  data    = [var.nginx_internal_lb_ip]
}

resource "yandex_dns_recordset" "temporal_internal" {
  count   = var.nginx_internal_lb_ip != "" ? 1 : 0
  zone_id = yandex_dns_zone.internal.id
  name    = "temporal.internal."
  type    = "A"
  ttl     = 60
  data    = [var.nginx_internal_lb_ip]
}

# ═════════════════════════════════════════════════════════════════════════════
# HashiCorp Vault – KMS auto-unseal resources
# ═════════════════════════════════════════════════════════════════════════════

resource "yandex_kms_symmetric_key" "vault" {
  name              = "prod-vault-kms"
  description       = "KMS key for HashiCorp Vault auto-unseal (prod)"
  folder_id         = var.yc_folder_id
  default_algorithm = "AES_256"
  rotation_period   = "8760h"  # 1 year
}

resource "yandex_iam_service_account" "vault" {
  name        = "prod-vault-sa"
  description = "Service account for HashiCorp Vault KMS auto-unseal (prod)"
  folder_id   = var.yc_folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "vault_kms" {
  folder_id = var.yc_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.vault.id}"
}

resource "yandex_iam_service_account_key" "vault" {
  service_account_id = yandex_iam_service_account.vault.id
  description        = "Authorized key for Vault KMS auto-unseal (prod)"
}

# ═════════════════════════════════════════════════════════════════════════════
# Loki Object Storage – log chunks (~40 Gi budget, 30-day retention)
# После apply передать в Ansible Vault:
#   tofu output -raw loki_s3_access_key | ansible-vault encrypt_string --stdin-name vault_loki_s3_access_key
#   tofu output -raw loki_s3_secret_key | ansible-vault encrypt_string --stdin-name vault_loki_s3_secret_key
# ═════════════════════════════════════════════════════════════════════════════
resource "yandex_iam_service_account" "loki" {
  name        = "prod-loki-sa"
  description = "Service account for Loki log storage (prod)"
  folder_id   = var.yc_folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "loki_storage_editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.loki.id}"
}

resource "yandex_iam_service_account_static_access_key" "loki" {
  service_account_id = yandex_iam_service_account.loki.id
  description        = "Static access key for Loki S3 log storage (prod)"

  depends_on = [yandex_resourcemanager_folder_iam_member.loki_storage_editor]
}

resource "yandex_storage_bucket" "loki" {
  bucket     = "prod-loki-logs-${var.yc_folder_id}"
  folder_id  = var.yc_folder_id
  access_key = yandex_iam_service_account_static_access_key.loki.access_key
  secret_key = yandex_iam_service_account_static_access_key.loki.secret_key

  lifecycle_rule {
    id      = "expire-old-logs"
    enabled = true

    expiration {
      days = 32  # 30 дней retention + 2 дня буфер для compactor
    }
  }

  depends_on = [yandex_iam_service_account_static_access_key.loki]
}

# ═════════════════════════════════════════════════════════════════════════════
# Object Storage – React SPA frontend (with CDN)
# ═════════════════════════════════════════════════════════════════════════════
module "object_storage" {
  source = "../../modules/object-storage"

  folder_id          = var.yc_folder_id
  env_name           = "prod"
  bucket_name        = "prod-frontend-${var.yc_folder_id}"
  versioning_enabled = true

  cdn_enabled = var.cdn_enabled
  cdn_cname   = var.cdn_cname
}
