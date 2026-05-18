# ──────────────────────────────────────────────────────────────────────────────
# VPC Module – Input Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "folder_id" {
  description = "Yandex Cloud folder ID"
  type        = string
}

variable "env_name" {
  description = "Environment name used as prefix (stage, prod, infra)"
  type        = string
}

variable "public_subnets" {
  description = "Map of zone → CIDR for public subnets"
  type        = map(string)
  default = {
    "ru-central1-a" = "10.10.1.0/24"
  }
}

variable "private_subnets" {
  description = "Map of zone → CIDR for private subnets"
  type        = map(string)
  default = {
    "ru-central1-a" = "10.10.2.0/24"
  }
}

variable "vpn_cidrs" {
  description = "CIDR blocks of the Netbird VPN network (used in security group rules)"
  type        = list(string)
  default     = ["100.64.0.0/10"]
}

variable "additional_allowed_cidrs" {
  description = "Additional CIDR blocks to allow in allow_internal security group (e.g., other VPCs for VPN routing)"
  type        = list(string)
  default     = []
}

variable "create_vpc" {
  description = "Whether to create a new VPC (true) or reuse an existing one (false)"
  type        = bool
  default     = true
}

variable "network_id" {
  description = "Existing VPC network ID to reuse (required if create_vpc = false)"
  type        = string
  default     = null
}
