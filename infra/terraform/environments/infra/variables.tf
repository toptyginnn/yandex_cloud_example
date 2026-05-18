# ──────────────────────────────────────────────────────────────────────────────
# Infra Environment – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

# ── Yandex Cloud credentials ────────────────────────────────────────────────
variable "yc_token" {
  description = "Yandex Cloud OAuth or IAM token"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

# ── SSH ──────────────────────────────────────────────────────────────────────
variable "ssh_public_keys" {
  description = "List of SSH public keys for instance access"
  type        = list(string)
  default     = []
}

# ── Ubuntu image ─────────────────────────────────────────────────────────────
variable "ubuntu_image_id" {
  description = "Yandex Cloud image ID for Ubuntu 22.04 LTS"
  type        = string
}

# ── GitLab ───────────────────────────────────────────────────────────────────
variable "gitlab_external_url" {
  description = "External URL for GitLab CE"
  type        = string
  default     = "http://gitlab.example.com"
}

variable "gitlab_instance_cores" {
  description = "Number of vCPUs for GitLab VM"
  type        = number
  default     = 2
}

variable "gitlab_instance_memory_gb" {
  description = "RAM in GB for GitLab VM"
  type        = number
  default     = 4
}

variable "gitlab_boot_disk_size_gb" {
  description = "Boot disk size in GB for GitLab VM"
  type        = number
  default     = 30
}

variable "gitlab_data_disk_size_gb" {
  description = "Separate data disk size in GB for GitLab persistent data"
  type        = number
  default     = 50
}

variable "gitlab_backup_bt6_bucket_enabled" {
  description = "Create private Object Storage bucket for GitLab backups"
  type        = bool
  default     = true
}

variable "gitlab_backup_bt6_bucket_name" {
  description = "Object Storage bucket name for GitLab backups"
  type        = string
  default     = ""
}

# ── Mailcow ──────────────────────────────────────────────────────────────────
variable "mailcow_instance_cores" {
  description = "Number of vCPUs for Mailcow VM"
  type        = number
  default     = 2
}

variable "mailcow_instance_memory_gb" {
  description = "RAM in GB for Mailcow VM"
  type        = number
  default     = 4
}

variable "mailcow_boot_disk_size_gb" {
  description = "Boot disk size in GB for Mailcow VM"
  type        = number
  default     = 30
}

variable "mailcow_data_disk_size_gb" {
  description = "Data disk size in GB for mail storage"
  type        = number
  default     = 50
}

variable "gitlab_backup_bt6_bucket_versioning_enabled" {
  description = "Enable bucket versioning for GitLab backups"
  type        = bool
  default     = false
}
