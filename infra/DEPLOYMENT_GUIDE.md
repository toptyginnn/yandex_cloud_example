# Deployment Guide – Yandex Cloud / OpenTofu

This guide describes how to deploy the infrastructure with OpenTofu from `terraform/`
and configure software on the VMs with Ansible from `ansible/`.

## 1. Prerequisites

1. **CLI tools:** `yc`, `tofu` (or `terraform`), `ansible`, `kubectl`, `helm`, `jq`, `yq`, `make`
2. **State bucket:** Create Object Storage bucket `tfstate-myapp` in `ru-central1`
3. **Credentials:** Export env vars (recommended)
   ```bash
   export TF_VAR_yc_token="<oauth-or-iam-token>"
   export TF_VAR_wg_easy_init_password="<NetBird-admin-password>"
   ```
   DB passwords are managed via Ansible Vault (not Terraform) for all environments.
4. **SSH key:** Provide `ssh_public_keys` in `terraform/environments/*/terraform.tfvars`
5. **Domains (optional):** For GitLab/public frontend, set real DNS A/CNAME to issued public IPs/CDN; otherwise use public IP directly.

## 2. Environments and Order

Apply in this order:
1) OpenTofu from `terraform/` creates VM/network/storage infrastructure
2) Ansible from `ansible/` configures VPN (`NetBird` + `caddy`)
3) Ansible from `ansible/` configures GitLab server and GitLab runners

Teardown is the reverse: prod → stage → infra.

## 3. OpenTofu Commands

```bash
# Initialize / plan / apply per environment
cd terraform
make init  ENV=infra
make plan  ENV=infra
make apply ENV=infra

# Show outputs
make output ENV=infra

# Full chain
make deploy-all

# Destroy (careful)
make destroy ENV=stage

# Format / clean
make fmt
make clean-all
```

## 4. Infra Environment (VPN + GitLab server public)

### What it creates
- `infra-vpc` with public+private subnets, NAT GW, security groups
- NetBird VPN server (static IP)
- GitLab CE server (static public IP; 80/443/22 open) on public subnet

### Steps
1. `cd terraform && make apply ENV=infra`
2. Note outputs:
   - `gitlab_public_ip` – add DNS A record (optional)
   - `gitlab_external_url` – ensure it matches DNS or `http://<public_ip>`
   - `vpn_public_ip` – use to configure NetBird clients
3. Run `ansible-playbook playbooks/vpn.yml` from `ansible/`
4. Run `ansible-playbook playbooks/gitlab-server.yml` from `ansible/`
5. Create `gitlab_runner_token` in GitLab UI and place it into `ansible/group_vars/all.yml`

## 5. Stage Environment

### What it creates
- `stage-vpc`, private k8s API (no public IP)
- Managed K8s cluster (ru-central1-b, 2 preemptible nodes)
- PostgreSQL via CloudNativePG operator (PVC 10Gi, StorageClass `yc-network-ssd`)
- Redis via raw k8s Deployment (`redis:7-alpine`, no persistence)
- Temporal (single replica, embedded PG)
- Vaultwarden (internal ingress)
- Frontend bucket (website hosting)

### Steps
1. `cd terraform && make apply ENV=stage`
2. `cd ansible && ansible-playbook playbooks/gitlab-runner.yml --limit stage-runner`
3. Fetch kubeconfig: `yc managed-kubernetes cluster get-credentials --id <cluster_id> --internal`
4. Verify: `kubectl get pods -A`
5. Upload SPA: `aws s3 cp build/ s3://<frontend_bucket>/ --recursive`

## 6. Prod Environment

### What it creates
- `prod-vpc`, regional k8s masters (ru-central1-a,b), autoscaling nodes (2–5)
- PostgreSQL via CloudNativePG operator (PVC 20Gi, 2 instances, StorageClass `yc-network-ssd`)
- Redis via raw k8s Deployment (`redis:7-alpine`, no persistence)
- Temporal (3 replicas) using in-cluster CNPG
- Vaultwarden (internal ingress)
- Frontend bucket (+ optional CDN)
- Loki logs in Yandex Object Storage (30-day retention)

### Steps
1. `cd terraform && make apply ENV=prod`
2. Note outputs:
   - `tofu output -raw vault_kms_key_id` → `hashicorp_vault_kms_key_id` в `group_vars/k8s_apps_prod/vars.yml`
   - `tofu output -raw vault_sa_authorized_key | ansible-vault encrypt_string` → `vault_hashicorp_vault_kms_auth_json` в vault.yml
   - `tofu output -raw loki_s3_bucket_name` → `loki_s3_bucket_name`
   - `tofu output -raw loki_s3_access_key | ansible-vault encrypt_string` → `vault_loki_s3_access_key`
   - `tofu output -raw loki_s3_secret_key | ansible-vault encrypt_string` → `vault_loki_s3_secret_key`
   - `tofu output -json private_subnet_ids | jq -r '."ru-central1-b"'` → `nginx_ingress_lb_subnet_id`
   - `tofu output -raw nginx_external_ip` → `nginx_ingress_external_lb_ip`
3. `cd ansible && ansible-playbook playbooks/gitlab-runner.yml --limit prod-runner`
4. Fetch kubeconfig: `make kubeconfig ENV=prod`
5. `make k8s-apps-prod` (деплоит nginx-ingress, cert-manager, CNPG, Redis, Temporal, Vaultwarden, Keycloak, Monitoring, Loki)
6. После деплоя nginx-ingress: заполни `nginx_ingress_internal_lb_ip` и перезапусти `tofu apply ENV=prod` для DNS-записей
7. `ansible-playbook playbooks/cnpg-databases-prod.yml` (создаёт БД: app_backend, temporal, keycloak, app_backend)
8. `ansible-playbook playbooks/hashicorp-vault-prod.yml`
9. If using CDN, configure CNAME to CDN endpoint.

## 7. Post-Deployment Checks

- VPN: `wg show` on client; ping k8s API and GitLab internal IPs
- GitLab: Access via `http(s)://gitlab_external_url`, create root password
- Runners: In GitLab admin, confirm runners tagged `stage` / `prod` are online
- K8s: `kubectl get nodes`, `kubectl get pods -A`
- Databases: connect from a k8s pod to PG/Redis service endpoints
- Temporal: Run a sample worker against `temporal-frontend.temporal.svc.cluster.local:7233`
- Vaultwarden: Access via internal ingress host (e.g., `vault.internal`), verify admin token from Lockbox

## 8. Security Notes

- GitLab SG: 80/443/22 open to 0.0.0.0/0; keep strong SSH keys and root password
- DBs and k8s API: no public IPs; reachable only over VPN/VPC
- Secrets: always via `TF_VAR_*` → Lockbox, never commit secrets
- Runners: private subnet only, internet egress through NAT GW

## 9. Updates / Changes

- Change GitLab infra vars: update `gitlab_external_url` in `terraform/environments/infra/terraform.tfvars` and re-apply OpenTofu
- Change application config: update variables in `ansible/group_vars/all.yml`
- Toggle CDN: set `cdn_enabled`/`cdn_cname` in prod tfvars and re-apply
