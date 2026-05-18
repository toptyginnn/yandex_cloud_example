terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC Module – networks, subnets, NAT gateway, security groups
# ──────────────────────────────────────────────────────────────────────────────

# ── Network ──────────────────────────────────────────────────────────────────
resource "yandex_vpc_network" "this" {
  count = var.create_vpc ? 1 : 0

  name        = "${var.env_name}-vpc"
  description = "VPC for ${var.env_name} environment"
  folder_id   = var.folder_id
}

# ── Public Subnet (one per zone) ─────────────────────────────────────────────
resource "yandex_vpc_subnet" "public" {
  for_each = var.public_subnets

  name           = "${var.env_name}-public-${each.key}"
  description    = "Public subnet in ${each.key}"
  folder_id      = var.folder_id
  network_id     = local.network_id
  zone           = each.key
  v4_cidr_blocks = [each.value]
}

# ── NAT Gateway for private subnets ─────────────────────────────────────────
resource "yandex_vpc_gateway" "nat" {
  name      = "${var.env_name}-nat-gw"
  folder_id = var.folder_id

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private" {
  name       = "${var.env_name}-private-rt"
  folder_id  = var.folder_id
  network_id = local.network_id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

# ── Private Subnet (one per zone) ───────────────────────────────────────────
resource "yandex_vpc_subnet" "private" {
  for_each = var.private_subnets

  name           = "${var.env_name}-private-${each.key}"
  description    = "Private subnet in ${each.key}"
  folder_id      = var.folder_id
  network_id     = local.network_id
  zone           = each.key
  v4_cidr_blocks = [each.value]
  route_table_id = yandex_vpc_route_table.private.id
}

# ── Security Group: allow-internal ───────────────────────────────────────────
resource "yandex_vpc_security_group" "allow_internal" {
  name        = "${var.env_name}-allow-internal"
  description = "Allow all traffic within the VPC CIDRs"
  folder_id   = var.folder_id
  network_id  = local.network_id

  dynamic "ingress" {
    for_each = local.all_cidrs
    content {
      description    = "Allow inbound from ${ingress.value}"
      protocol       = "ANY"
      v4_cidr_blocks = [ingress.value]
    }
  }

  dynamic "egress" {
    for_each = local.all_cidrs
    content {
      description    = "Allow outbound to ${egress.value}"
      protocol       = "ANY"
      v4_cidr_blocks = [egress.value]
    }
  }

  egress {
    description    = "Allow outbound to internet"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-vpn ───────────────────────────────────────────────
resource "yandex_vpc_security_group" "allow_vpn" {
  name        = "${var.env_name}-allow-vpn"
  description = "Allow Netbird/SSH/Web ingress for VPN gateway"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "SSH inbound"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTP inbound"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS TCP inbound"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS UDP (QUIC) inbound"
    protocol       = "UDP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "TURN/STUN inbound"
    protocol       = "UDP"
    port           = 3478
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "TURN relay ports"
    protocol       = "UDP"
    from_port      = 49152
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-k8s-api ───────────────────────────────────────────
resource "yandex_vpc_security_group" "allow_k8s_api" {
  name        = "${var.env_name}-allow-k8s-api"
  description = "Allow TCP 443 to k8s API from VPN subnet only"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "k8s API from VPN subnet"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = var.vpn_cidrs
  }

  ingress {
    description    = "k8s API from internal subnets"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = local.all_cidrs
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-ssh ────────────────────────────────────────────────
resource "yandex_vpc_security_group" "allow_ssh" {
  name        = "${var.env_name}-allow-ssh"
  description = "Allow SSH from VPN subnet only"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "SSH from VPN"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.vpn_cidrs
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-web ────────────────────────────────────────────────
resource "yandex_vpc_security_group" "allow_web" {
  name        = "${var.env_name}-allow-web"
  description = "Allow HTTP/HTTPS inbound from VPN"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = var.vpn_cidrs
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = var.vpn_cidrs
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-gitlab-public (80/443/22/2222 from 0.0.0.0/0) ─────
resource "yandex_vpc_security_group" "allow_gitlab_public" {
  name        = "${var.env_name}-allow-gitlab-public"
  description = "Public access for GitLab (HTTP/HTTPS/SSH)"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "GitLab HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "GitLab HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "GitLab SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "GitLab SSH (container port mapping)"
    protocol       = "TCP"
    port           = 2222
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-mailcow-public ─────────────────────────────────────
resource "yandex_vpc_security_group" "allow_mailcow_public" {
  name        = "${var.env_name}-allow-mailcow-public"
  description = "Public access for Mailcow mail server (SMTP/IMAP/POP3/Web)"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "SMTP inbound (MX delivery)"
    protocol       = "TCP"
    port           = 25
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTP inbound (webmail + ACME)"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "IMAP inbound"
    protocol       = "TCP"
    port           = 143
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS inbound (webmail)"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "SMTPS inbound"
    protocol       = "TCP"
    port           = 465
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "SMTP Submission inbound"
    protocol       = "TCP"
    port           = 587
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "IMAPS inbound"
    protocol       = "TCP"
    port           = 993
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "POP3S inbound"
    protocol       = "TCP"
    port           = 995
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Sieve inbound (mail filtering)"
    protocol       = "TCP"
    port           = 4190
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Security Group: allow-nlb-healthchecks ───────────────────────────────────
resource "yandex_vpc_security_group" "allow_nlb_healthchecks" {
  name        = "${var.env_name}-allow-nlb-healthchecks"
  description = "Allow YC NLB health checks and NodePort range for internal LoadBalancer services"
  folder_id   = var.folder_id
  network_id  = local.network_id

  ingress {
    description    = "YC NLB health check source 1"
    protocol       = "ANY"
    v4_cidr_blocks = ["198.18.235.0/24"]
  }

  ingress {
    description    = "YC NLB health check source 2"
    protocol       = "ANY"
    v4_cidr_blocks = ["198.18.248.0/24"]
  }

  ingress {
    description    = "NodePort range from internal subnets"
    protocol       = "TCP"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = local.all_cidrs
  }

  ingress {
    description    = "NodePort range from internet (external NLB traffic)"
    protocol       = "TCP"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Locals ───────────────────────────────────────────────────────────────────
locals {
  network_id   = var.create_vpc ? yandex_vpc_network.this[0].id : var.network_id
  network_name = var.create_vpc ? yandex_vpc_network.this[0].name : "${var.env_name}-vpc"
  all_cidrs    = concat(values(var.public_subnets), values(var.private_subnets), var.vpn_cidrs, var.additional_allowed_cidrs)
}
