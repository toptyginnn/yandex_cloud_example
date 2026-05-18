# ──────────────────────────────────────────────────────────────────────────────
# Stage Environment – Input Variables
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

variable "ubuntu_image_id" {
  description = "Yandex Cloud image ID for Ubuntu 22.04 LTS"
  type        = string
}

# ── VPN ──────────────────────────────────────────────────────────────────────
variable "vpn_cidrs" {
  description = "VPN tunnel CIDRs (used for security group rules)"
  type        = list(string)
  default     = ["10.66.0.0/24"]
}

# ── GitLab Runner ────────────────────────────────────────────────────────────
variable "gitlab_external_url" {
  description = "External URL of GitLab server deployed in infra"
  type        = string
  default     = "https://gitlab.myapp.example.com"
}

variable "runner_registration_token" {
  description = "GitLab runner registration token"
  type        = string
  sensitive   = true
}

variable "runner_tag_list" {
  description = "Comma-separated list of tags for stage runner"
  type        = string
  default     = "stage,docker"
}

# ── DNS ───────────────────────────────────────────────────────────────────────
variable "nginx_internal_lb_ip" {
  description = "IP of nginx-ingress internal LoadBalancer (set after first nginx-ingress deploy)"
  type        = string
  default     = ""
}
