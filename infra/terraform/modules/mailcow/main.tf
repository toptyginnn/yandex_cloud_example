terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Mailcow Module – dedicated mail server (Docker Compose on Ubuntu VM)
# ──────────────────────────────────────────────────────────────────────────────

# ── Static external IP ───────────────────────────────────────────────────────
resource "yandex_vpc_address" "mailcow" {
  name      = "${var.env_name}-mailcow-ip"
  folder_id = var.folder_id

  external_ipv4_address {
    zone_id = var.zone
  }
}

# ── Separate data disk for mail storage ──────────────────────────────────────
resource "yandex_compute_disk" "mailcow_data" {
  name      = "${var.env_name}-mailcow-data"
  folder_id = var.folder_id
  zone      = var.zone
  size      = var.data_disk_size_gb
  type      = "network-hdd"
}

# ── Mailcow Server Instance ───────────────────────────────────────────────────
resource "yandex_compute_instance" "mailcow" {
  name        = "${var.env_name}-mailcow"
  hostname    = "${var.env_name}-mailcow"
  folder_id   = var.folder_id
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = var.instance_cores
    memory = var.instance_memory_gb
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = var.boot_disk_size_gb
      type     = "network-ssd"
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.mailcow_data.id
    device_name = "mailcow-data"
    auto_delete = false
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = true
    nat_ip_address     = yandex_vpc_address.mailcow.external_ipv4_address[0].address
    security_group_ids = var.security_group_ids
  }

  metadata = {
    user-data = templatefile("${path.module}/templates/mailcow-cloud-init.yaml", {
      ssh_public_keys    = var.ssh_public_keys
      data_disk_device   = "/dev/vdb"
      data_mount_path    = "/opt/mailcow-data"
    })
    ssh-keys = join("\n", [for key in var.ssh_public_keys : "ubuntu:${key}"])
  }

  scheduling_policy {
    preemptible = false
  }

  labels = {
    env  = var.env_name
    role = "mailcow"
  }
}
