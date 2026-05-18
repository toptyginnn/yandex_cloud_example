# ──────────────────────────────────────────────────────────────────────────────
# GitLab Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name prefix (infra)"
  type        = string
  default     = "infra"
}

variable "zone" {
  description = "Availability zone"
  type        = string
  default     = "ru-central1-a"
}

# ── Network – GitLab server (public) ─────────────────────────────────────────
variable "gitlab_subnet_id" {
  description = "Subnet ID for the GitLab server (public subnet, gets a static NAT IP)"
  type        = string
  nullable    = true
  default     = null
}

variable "gitlab_security_group_ids" {
  description = "Security group IDs for the GitLab server (allow 80/443/22 from 0.0.0.0/0)"
  type        = list(string)
  default     = []
}

# ── Network – Runners (private) ──────────────────────────────────────────────
variable "runner_subnet_id" {
  description = "Subnet ID for GitLab runners (private, reach internet via NAT gateway)"
  type        = string
  nullable    = true
  default     = null
}

variable "runner_security_group_ids" {
  description = "Security group IDs for the GitLab runners"
  type        = list(string)
  default     = []
}

variable "runner_count" {
  description = "Number of GitLab runner instances"
  type        = number
  default     = 2
}

variable "create_gitlab_server" {
  description = "Whether to create GitLab CE server instance"
  type        = bool
  default     = true
}

variable "create_runners" {
  description = "Whether to create GitLab Runner instances"
  type        = bool
  default     = true
}

# ── GitLab server sizing & storage ───────────────────────────────────────────
variable "gitlab_instance_cores" {
  description = "Number of vCPUs for the GitLab server instance"
  type        = number
  default     = 2
}

variable "gitlab_instance_memory_gb" {
  description = "RAM in GB for the GitLab server instance"
  type        = number
  default     = 4
}

variable "gitlab_boot_disk_size_gb" {
  description = "Boot disk size in GB for the GitLab server instance"
  type        = number
  default     = 30
}

variable "gitlab_boot_disk_type" {
  description = "Boot disk type for the GitLab server instance"
  type        = string
  default     = "network-ssd"
}

variable "gitlab_data_disk_size_gb" {
  description = "Separate data disk size in GB for GitLab persistent data"
  type        = number
  default     = 50
}

variable "gitlab_data_disk_type" {
  description = "Separate data disk type for GitLab persistent data"
  type        = string
  default     = "network-ssd"
}

variable "gitlab_data_disk_device" {
  description = "Linux device path for the attached GitLab data disk"
  type        = string
  default     = "/dev/vdb"
}

variable "gitlab_data_mount_path" {
  description = "Mount path for GitLab persistent data disk"
  type        = string
  default     = "/opt/gitlab/data"
}

# ── Images & Keys ────────────────────────────────────────────────────────────
variable "ubuntu_image_id" {
  description = "Yandex Cloud image ID for Ubuntu 22.04 LTS"
  type        = string
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to inject into the instances"
  type        = list(string)
}

# ── GitLab configuration ──────────────────────────────────────────────────────
variable "gitlab_external_url" {
  description = "External URL for GitLab CE (e.g. https://gitlab.example.com or http://<public_ip>)"
  type        = string
  default     = "http://gitlab.example.com"
}

variable "runner_registration_token" {
  description = "GitLab runner registration token (from Lockbox)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "runner_tag_list" {
  description = "Comma-separated list of tags for runners (e.g. stage,prod)"
  type        = string
  default     = "shared"
}

# ── GitLab backup bucket (S3 API) ────────────────────────────────────────────
variable "create_gitlab_backup_bt6_bucket" {
  description = "Whether to create a private Object Storage bucket for GitLab backups"
  type        = bool
  default     = false
}

variable "gitlab_backup_bt6_bucket_name" {
  description = "Name of the Object Storage bucket for GitLab backups"
  type        = string
  default     = ""
}

variable "gitlab_backup_bt6_bucket_versioning_enabled" {
  description = "Enable versioning for the GitLab backup bucket"
  type        = bool
  default     = true
}
