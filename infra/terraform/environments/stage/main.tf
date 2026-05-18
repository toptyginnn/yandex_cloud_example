# ──────────────────────────────────────────────────────────────────────────────
# Stage Environment – Module Wiring
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
    key    = "stage/terraform.tfstate"
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
  zone      = "ru-central1-b"
}

# ═════════════════════════════════════════════════════════════════════════════
# VPC – stage-vpc
# ═════════════════════════════════════════════════════════════════════════════
module "vpc" {
  source = "../../modules/vpc"

  folder_id = var.yc_folder_id
  env_name  = "stage"
  create_vpc = false
  network_id = "enpvduk371cj2jfnt683"

  public_subnets = {
    "ru-central1-b" = "10.10.1.0/24"
  }

  private_subnets = {
    "ru-central1-b" = "10.10.2.0/24"
  }

  vpn_cidrs = var.vpn_cidrs

  additional_allowed_cidrs = [
    "10.20.1.23/32",
    "10.20.1.22/32",
    "10.112.0.0/16", # K8s pod CIDR (Calico BGP routing — cross-node pod traffic)
    "10.96.0.0/16",  # K8s service CIDR
  ]
}

# ═════════════════════════════════════════════════════════════════════════════
# GitLab Runner – stage only (GitLab server is in infra)
# ═════════════════════════════════════════════════════════════════════════════
module "gitlab_runner" {
  source = "../../modules/gitlab"

  folder_id = var.yc_folder_id
  env_name  = "stage"
  zone      = "ru-central1-b"

  create_gitlab_server = false
  create_runners       = true
  runner_count         = 1

  runner_subnet_id = module.vpc.private_subnet_ids["ru-central1-b"]
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
# Kubernetes – stage cluster
# ═════════════════════════════════════════════════════════════════════════════
module "k8s" {
  source = "../../modules/k8s"

  folder_id  = var.yc_folder_id
  env_name   = "stage"
  network_id = module.vpc.network_id

  master_zones      = ["ru-central1-b"]
  master_subnet_ids = module.vpc.private_subnet_ids

  master_security_group_ids = [
    module.vpc.sg_allow_internal_id,
    module.vpc.sg_allow_k8s_api_id,
  ]

  node_zones      = ["ru-central1-b"]
  node_subnet_ids = module.vpc.private_subnet_ids

  node_security_group_ids = [
    module.vpc.sg_allow_internal_id,
    module.vpc.sg_allow_nlb_healthchecks_id,
  ]

  node_cores         = 4
  node_core_fraction = 50
  node_memory_gb     = 8
  node_disk_size_gb  = 64
  node_disk_type     = "network-hdd"
  node_preemptible   = true
  node_auto_scaling = false
  node_fixed_count  = 2

  ssh_public_keys = var.ssh_public_keys
}

# ═════════════════════════════════════════════════════════════════════════════
# Private DNS – *.internal
# ═════════════════════════════════════════════════════════════════════════════
resource "yandex_dns_zone" "internal" {
  name             = "stage-internal"
  zone             = "internal."
  folder_id        = var.yc_folder_id
  description      = "Private DNS zone for internal services (stage)"
  private_networks = [module.vpc.network_id]
}

resource "yandex_dns_recordset" "vault_internal" {
  count   = var.nginx_internal_lb_ip != "" ? 1 : 0
  zone_id = yandex_dns_zone.internal.id
  name    = "vault.internal."
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
  name              = "stage-vault-kms"
  description       = "KMS key for HashiCorp Vault auto-unseal (stage)"
  folder_id         = var.yc_folder_id
  default_algorithm = "AES_256"
  rotation_period   = "8760h"  # 1 year
}

resource "yandex_iam_service_account" "vault" {
  name        = "stage-vault-sa"
  description = "Service account for HashiCorp Vault KMS auto-unseal (stage)"
  folder_id   = var.yc_folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "vault_kms" {
  folder_id = var.yc_folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.vault.id}"
}

resource "yandex_iam_service_account_key" "vault" {
  service_account_id = yandex_iam_service_account.vault.id
  description        = "Authorized key for Vault KMS auto-unseal (stage)"
}

# ═════════════════════════════════════════════════════════════════════════════
# Object Storage – React SPA frontend
# ═════════════════════════════════════════════════════════════════════════════
module "object_storage" {
  source = "../../modules/object-storage"

  folder_id   = var.yc_folder_id
  env_name    = "stage"
  bucket_name = "stage-frontend-${var.yc_folder_id}"

  cdn_enabled = false
}
