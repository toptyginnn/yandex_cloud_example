# ──────────────────────────────────────────────────────────────────────────────
# VPN Module – Input Variables
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
  description = "Availability zone for the VPN instance"
  type        = string
  default     = "ru-central1-a"
}

variable "subnet_id" {
  description = "Subnet ID to place the VPN instance in (public subnet of infra-vpc)"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the VPN instance"
  type        = list(string)
}

variable "ubuntu_image_id" {
  description = "Yandex Cloud image ID for Ubuntu 22.04 LTS"
  type        = string
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to inject into the instance"
  type        = list(string)
}
