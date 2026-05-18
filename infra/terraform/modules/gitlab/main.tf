terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# GitLab Module – GitLab CE server and/or private runners
# ──────────────────────────────────────────────────────────────────────────────

# ── Static external IP for GitLab ────────────────────────────────────────────
resource "yandex_vpc_address" "gitlab" {
  count = var.create_gitlab_server ? 1 : 0

  name      = "${var.env_name}-gitlab-ip"
  folder_id = var.folder_id

  external_ipv4_address {
    zone_id = var.zone
  }
}

# ── Separate data disk for GitLab persistent data ────────────────────────────
resource "yandex_compute_disk" "gitlab_data" {
  count = var.create_gitlab_server ? 1 : 0

  name      = "${var.env_name}-gitlab-data"
  folder_id = var.folder_id
  zone      = var.zone
  size      = var.gitlab_data_disk_size_gb
  type      = var.gitlab_data_disk_type
}

# ── GitLab CE Server (PUBLIC — accessible from the internet) ─────────────────
resource "yandex_compute_instance" "gitlab" {
  count = var.create_gitlab_server ? 1 : 0

  name        = "${var.env_name}-gitlab"
  hostname    = "${var.env_name}-gitlab"
  folder_id   = var.folder_id
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = var.gitlab_instance_cores
    memory = var.gitlab_instance_memory_gb
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = var.gitlab_boot_disk_size_gb
      type     = var.gitlab_boot_disk_type
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.gitlab_data[0].id
    device_name = "gitlab-data"
    auto_delete = false
  }

  network_interface {
    subnet_id          = var.gitlab_subnet_id
    nat                = true
    nat_ip_address     = yandex_vpc_address.gitlab[0].external_ipv4_address[0].address
    security_group_ids = var.gitlab_security_group_ids
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/gitlab-cloud-init.yaml", {
      gitlab_external_url = var.gitlab_external_url
      ssh_public_keys     = var.ssh_public_keys
      data_disk_device    = var.gitlab_data_disk_device
      data_mount_path     = var.gitlab_data_mount_path
    })
    ssh-keys = join("\n", [for key in var.ssh_public_keys : "ubuntu:${key}"])
  }

  scheduling_policy {
    preemptible = false
  }

  labels = {
    env  = var.env_name
    role = "gitlab"
  }
}

# ── Object Storage bucket for GitLab backups (S3 API) ────────────────────────
resource "yandex_iam_service_account" "gitlab_backup_bt6_storage" {
  count = var.create_gitlab_backup_bt6_bucket && var.gitlab_backup_bt6_bucket_name != "" ? 1 : 0

  name        = "${var.env_name}-gitlab-backup-sa"
  description = "Service account for GitLab backup bucket in ${var.env_name}"
  folder_id   = var.folder_id
}

resource "yandex_resourcemanager_folder_iam_member" "gitlab_backup_bt6_storage_editor" {
  count = var.create_gitlab_backup_bt6_bucket && var.gitlab_backup_bt6_bucket_name != "" ? 1 : 0

  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.gitlab_backup_bt6_storage[0].id}"
}

resource "yandex_iam_service_account_static_access_key" "gitlab_backup_bt6_storage" {
  count = var.create_gitlab_backup_bt6_bucket && var.gitlab_backup_bt6_bucket_name != "" ? 1 : 0

  service_account_id = yandex_iam_service_account.gitlab_backup_bt6_storage[0].id
  description        = "Static access key for ${var.env_name} GitLab backup bucket"
}

resource "yandex_storage_bucket" "gitlab_backup_bt6" {
  count = var.create_gitlab_backup_bt6_bucket && var.gitlab_backup_bt6_bucket_name != "" ? 1 : 0

  bucket     = var.gitlab_backup_bt6_bucket_name
  folder_id  = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.gitlab_backup_bt6_storage[0].access_key
  secret_key = yandex_iam_service_account_static_access_key.gitlab_backup_bt6_storage[0].secret_key

  acl = "private"

  versioning {
    enabled = var.gitlab_backup_bt6_bucket_versioning_enabled
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.gitlab_backup_bt6_storage_editor
  ]
}

# ── GitLab Runners (PRIVATE — no public access, reach internet via NAT GW) ──
resource "yandex_compute_instance" "runner" {
  count = var.create_runners ? var.runner_count : 0

  name        = "${var.env_name}-gitlab-runner-${count.index + 1}"
  hostname    = "${var.env_name}-gitlab-runner-${count.index + 1}"
  folder_id   = var.folder_id
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = 50
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = var.runner_subnet_id
    nat                = false
    security_group_ids = var.runner_security_group_ids
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/runner-cloud-init.yaml", {
      gitlab_url                = var.gitlab_external_url
      runner_registration_token = var.runner_registration_token
      runner_tag_list           = var.runner_tag_list
      runner_name               = "${var.env_name}-runner-${count.index + 1}"
      ssh_public_keys           = var.ssh_public_keys
    })
  }

  scheduling_policy {
    preemptible = false
  }

  labels = {
    env  = var.env_name
    role = "gitlab-runner"
  }
}
