# ──────────────────────────────────────────────────────────────────────────────
# Infra Environment – VPN + GitLab (shared infrastructure)
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
    key    = "infra/terraform.tfstate"
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
# VPC – infra-vpc
# ═════════════════════════════════════════════════════════════════════════════
module "vpc" {
  source = "../../modules/vpc"

  folder_id = var.yc_folder_id
  env_name  = "infra"

  public_subnets = {
    "ru-central1-a" = "10.20.1.0/24"
  }

  private_subnets = {
    "ru-central1-a" = "10.20.2.0/24"
  }

  vpn_cidrs = ["100.64.0.0/10"]
  
  # Allow traffic from stage and prod VPCs through VPN server
  additional_allowed_cidrs = ["10.10.0.0/16", "10.30.0.0/16"]
}

# ═════════════════════════════════════════════════════════════════════════════
# VPN – WireGuard server
# ═════════════════════════════════════════════════════════════════════════════
module "vpn" {
  source = "../../modules/vpn"

  folder_id = var.yc_folder_id
  env_name  = "infra"
  zone      = "ru-central1-a"

  subnet_id = module.vpc.public_subnet_ids["ru-central1-a"]

  security_group_ids = [
    module.vpc.sg_allow_vpn_id,
    module.vpc.sg_allow_internal_id,
  ]

  ubuntu_image_id = var.ubuntu_image_id
  ssh_public_keys = var.ssh_public_keys
}

# ═════════════════════════════════════════════════════════════════════════════
# Container Registry – shared private Docker registry
# ═════════════════════════════════════════════════════════════════════════════
module "container_registry" {
  source = "../../modules/container-registry"

  folder_id     = var.yc_folder_id
  registry_name = "bt6"
}

# ═════════════════════════════════════════════════════════════════════════════
# Mailcow – dedicated mail server
# ═════════════════════════════════════════════════════════════════════════════
module "mailcow" {
  source = "../../modules/mailcow"

  folder_id = var.yc_folder_id
  env_name  = "infra"
  zone      = "ru-central1-a"

  subnet_id = module.vpc.public_subnet_ids["ru-central1-a"]

  security_group_ids = [
    module.vpc.sg_allow_mailcow_public_id,
    module.vpc.sg_allow_internal_id,
  ]

  ubuntu_image_id    = var.ubuntu_image_id
  ssh_public_keys    = var.ssh_public_keys

  instance_cores     = var.mailcow_instance_cores
  instance_memory_gb = var.mailcow_instance_memory_gb
  boot_disk_size_gb  = var.mailcow_boot_disk_size_gb
  data_disk_size_gb  = var.mailcow_data_disk_size_gb
}

# ═════════════════════════════════════════════════════════════════════════════
# GitLab – CE server only
# ═════════════════════════════════════════════════════════════════════════════
module "gitlab" {
  source = "../../modules/gitlab"

  folder_id        = var.yc_folder_id
  env_name         = "infra"
  zone             = "ru-central1-a"
  gitlab_subnet_id = module.vpc.public_subnet_ids["ru-central1-a"]
  create_runners   = false

  gitlab_security_group_ids = [
    module.vpc.sg_allow_gitlab_public_id,
    module.vpc.sg_allow_internal_id,
  ]

  ubuntu_image_id     = var.ubuntu_image_id
  ssh_public_keys     = var.ssh_public_keys
  gitlab_external_url = var.gitlab_external_url

  gitlab_instance_cores     = var.gitlab_instance_cores
  gitlab_instance_memory_gb = var.gitlab_instance_memory_gb
  gitlab_boot_disk_size_gb  = var.gitlab_boot_disk_size_gb
  gitlab_data_disk_size_gb  = var.gitlab_data_disk_size_gb

  create_gitlab_backup_bt6_bucket             = var.gitlab_backup_bt6_bucket_enabled
  gitlab_backup_bt6_bucket_name               = var.gitlab_backup_bt6_bucket_name
  gitlab_backup_bt6_bucket_versioning_enabled = var.gitlab_backup_bt6_bucket_versioning_enabled
}
