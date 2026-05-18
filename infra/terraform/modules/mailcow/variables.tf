# ──────────────────────────────────────────────────────────────────────────────
# Mailcow Module – Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name prefix (e.g. infra)"
  type        = string
}

variable "zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "subnet_id" {
  description = "Subnet ID to attach the Mailcow instance to (public subnet)"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the Mailcow instance"
  type        = list(string)
  default     = []
}

variable "ubuntu_image_id" {
  description = "Yandex Cloud image ID for Ubuntu 22.04 LTS"
  type        = string
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for instance access"
  type        = list(string)
  default     = []
}

variable "instance_cores" {
  description = "Number of vCPUs for Mailcow VM"
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "RAM in GB for Mailcow VM"
  type        = number
  default     = 8
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 30
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB for mail storage"
  type        = number
  default     = 50
}
