# Deployment Order — Dependency Graph & Apply Sequence

## Prerequisites

Before running OpenTofu and Ansible, ensure:

1. **S3 backend bucket** (`tfstate-bt6-infra`) exists in Yandex Object Storage
2. **Yandex Cloud CLI** (`yc`) is installed and authenticated
3. **OpenTofu** >= 1.6, **Ansible** with `kubernetes.core` collection, **Helm** CLI are installed
   ```bash
   ansible-galaxy collection install kubernetes.core
   ```
4. **Sensitive variables** are set via environment variables:
   ```bash
   # Terraform
   export TF_VAR_yc_token="<your-oauth-or-iam-token>"
   export TF_VAR_runner_registration_token="<gitlab-runner-token>"
   ```
   DB passwords for all environments are managed via **Ansible Vault** (not Terraform).

---

## Architecture: Two-Layer Deployment

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 1 – Terraform (cloud resources, changed rarely)       │
│                                                              │
│  VPC  K8s Cluster  GitLab Runner  Object Storage  KMS/IAM   │
└──────────────────────────────┬───────────────────────────────┘
                               │  tofu output k8s_cluster_id
                               │  make kubeconfig ENV=<env>
┌──────────────────────────────▼───────────────────────────────┐
│  Layer 2 – Ansible (K8s apps, changed on every deploy)       │
│                                                              │
│  stage: CloudNativePG · Redis · Temporal · Vaultwarden       │
│  prod:  CloudNativePG · Redis · Temporal · Vaultwarden       │
│         Keycloak · Monitoring · Loki · HashiCorp Vault       │
└──────────────────────────────────────────────────────────────┘
```

---

## Dependency Graph

```
                    ┌──────────────────┐
                    │  S3 State Bucket │  (manual / pre-existing)
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌──────────────┐ ┌───────────┐ ┌───────────┐
     │  INFRA ENV   │ │ STAGE ENV │ │ PROD ENV  │
     │  TF step 1   │ │ TF step 2 │ │ TF step 3 │
     └──────┬───────┘ └─────┬─────┘ └─────┬─────┘
            │               │              │
     ┌──────┴───────┐       │              │
     │              │       │              │
     ▼              ▼       ▼              ▼
  ┌──────┐   ┌────────┐  ┌─────┐    ┌──────────────┐
  │ VPN  │   │ GitLab │  │ K8s │    │  K8s cluster │
  │  VM  │   │+runner │  │stage│    │  KMS / IAM   │
  └──────┘   └────────┘  └──┬──┘    │  Loki S3     │
                             │       └──────┬───────┘
                             │              │
                    get-credentials  get-credentials
                             │              │
              ┌──────────────▼──┐  ┌────────▼────────────┐
              │ Ansible step 2a │  │   Ansible step 3a   │
              │  k8s-apps-stage │  │   k8s-apps-prod     │
              ├─────────────────┤  ├─────────────────────┤
              │ CloudNativePG   │  │ CloudNativePG       │
              │ Redis (Helm)    │  │ Redis (Helm)        │
              │ Temporal        │  │ Temporal            │
              │ Vaultwarden     │  │ Vaultwarden         │
              └─────────────────┘  │ Keycloak            │
                                   │ Monitoring + Loki   │
                                   ├─────────────────────┤
                                   │ cnpg-databases-prod │
                                   │ hashicorp-vault-prod│
                                   └─────────────────────┘
```

---

## Step-by-Step Apply Sequence

### Step 1: Infrastructure (Terraform)

**Why first:** VPN provides secure access to all other environments.
GitLab provides CI/CD for subsequent deployments.

```bash
cd terraform
make init  ENV=infra
make plan  ENV=infra
make apply ENV=infra
```

**Creates:** `infra-vpc`, WireGuard VPN server, GitLab CE server

**Post-apply:**
1. Note outputs: `make output ENV=infra`
2. Run: `ansible-playbook ansible/playbooks/vpn.yml`
3. Run: `ansible-playbook ansible/playbooks/gitlab-server.yml`
4. Connect to VPN before proceeding

---

### Step 2a: Stage Infrastructure (Terraform)

```bash
cd terraform
make init  ENV=stage
make plan  ENV=stage
make apply ENV=stage
```

**Creates:** `stage-vpc`, K8s cluster (2 preemptible nodes), GitLab Runner VM, Object Storage bucket

**Post-apply:**
```bash
# Register GitLab runner
ansible-playbook ansible/playbooks/gitlab-runner.yml --limit stage-runner

# Fetch kubeconfig for stage cluster
make kubeconfig ENV=stage
# equivalent: yc managed-kubernetes cluster get-credentials --id $(cd environments/stage && tofu output -raw k8s_cluster_id) --internal
```

---

### Step 2b: Stage K8s Apps (Ansible)

**Why separate:** K8s cluster must exist first. Apps deploy independently via Helm.

```bash
cd ansible
ansible-playbook playbooks/k8s-apps-stage.yml
```

**Installs in K8s:**
- CloudNativePG operator + Cluster (PostgreSQL 16, 1 instance, PVC 10Gi)
- Redis standalone via Bitnami Helm (no persistence)
- Temporal (single-node, embedded PostgreSQL)
- Vaultwarden (with Ingress, PVC 1Gi)

**Deploy single app:**
```bash
ansible-playbook playbooks/k8s-apps-stage.yml --tags cloudnative_pg
ansible-playbook playbooks/k8s-apps-stage.yml --tags temporal
```

---

### Step 3a: Prod Infrastructure (Terraform)

```bash
cd terraform
make clean ENV=prod   # обновит lock-файл (убрали helm/kubernetes провайдеры)
make init  ENV=prod
make plan  ENV=prod
make apply ENV=prod
```

**Creates:** `prod-vpc` (multi-zone a+b), K8s cluster (autoscaling 2–5, non-preemptible),
GitLab Runner VM, KMS key + SA для Vault auto-unseal, Loki S3 bucket, Object Storage + CDN

**Post-apply — собрать outputs:**
```bash
cd terraform

# Subnet для nginx LB (ru-central1-b)
tofu output -json private_subnet_ids -chdir=environments/prod | jq -r '."ru-central1-b"'

# Статический IP nginx-external
tofu output -raw nginx_external_ip -chdir=environments/prod

# KMS key для Vault
tofu output -raw vault_kms_key_id -chdir=environments/prod

# SA ключ для Vault (зашифровать в vault.yml)
tofu output -raw vault_sa_authorized_key -chdir=environments/prod \
  | ansible-vault encrypt_string --stdin-name vault_hashicorp_vault_kms_auth_json

# Loki S3
tofu output -raw loki_s3_bucket_name -chdir=environments/prod
tofu output -raw loki_s3_access_key  -chdir=environments/prod \
  | ansible-vault encrypt_string --stdin-name vault_loki_s3_access_key
tofu output -raw loki_s3_secret_key  -chdir=environments/prod \
  | ansible-vault encrypt_string --stdin-name vault_loki_s3_secret_key
```

**Заполнить в `ansible/inventories/group_vars/k8s_apps_prod/vars.yml`:**
- `nginx_ingress_lb_subnet_id` — subnet из output выше
- `nginx_ingress_external_lb_ip` — IP из output выше
- `hashicorp_vault_kms_key_id` — KMS key из output выше
- `loki_s3_bucket_name` — имя бакета

**Зашифрованные секреты добавить в `vault.yml`:**
- `vault_hashicorp_vault_kms_auth_json`
- `vault_loki_s3_access_key`
- `vault_loki_s3_secret_key`

**Регистрация runner:**
```bash
cd ansible
ansible-playbook playbooks/gitlab-runner.yml --limit prod-runner
```

**Kubeconfig:**
```bash
cd terraform && make kubeconfig ENV=prod
```

---

### Step 3b: Prod K8s Apps (Ansible)

```bash
cd ansible
ansible-playbook playbooks/k8s-apps-prod.yml
```

**Installs in K8s (в порядке ролей):**
1. nginx-ingress (external + internal LoadBalancer)
2. cert-manager (Let's Encrypt + internal CA)
3. CloudNativePG operator + Cluster `prod-pg` (2 instances, PVC 20Gi)
4. Redis standalone `prod-redis` (in-memory, no persistence)
5. Temporal (3 replicas, uses CNPG)
6. Vaultwarden (internal ingress)
7. Keycloak (external ingress, uses CNPG)
8. kube-prometheus-stack + Grafana
9. Loki + Promtail (логи в S3)

**После nginx-ingress:** получи internal LB IP и заполни `nginx_ingress_internal_lb_ip`,
затем `tofu apply ENV=prod` для создания DNS-записей (`vault.internal`, `hcvault.internal`, `temporal.internal`).

---

### Step 3c: CNPG Databases (Ansible)

```bash
cd ansible
ansible-playbook playbooks/cnpg-databases-prod.yml
```

**Creates logical databases in `prod-pg`:**
- `bt6_backend` / owner `bt6_backend`
- `temporal` / owner `temporal`
- `temporal_visibility` / owner `temporal`
- `keycloak` / owner `keycloak`
- `app_backend` / owner `app_backend`

> Запускать после того как CNPG кластер поднялся (шаг 3b завершён).

---

### Step 3d: HashiCorp Vault (Ansible)

```bash
cd ansible
ansible-playbook playbooks/hashicorp-vault-prod.yml
```

**После установки — ручная инициализация:**
```bash
kubectl -n vault exec -it vault-0 -- vault operator init
# Сохрани unseal keys и root token в надёжное место!

kubectl -n vault exec -it vault-0 -- vault operator unseal <KEY1>
kubectl -n vault exec -it vault-0 -- vault operator unseal <KEY2>
kubectl -n vault exec -it vault-0 -- vault operator unseal <KEY3>

# Присоединить vault-1 и vault-2 к Raft кластеру:
kubectl -n vault exec -it vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl -n vault exec -it vault-1 -- vault operator unseal <KEY1>
kubectl -n vault exec -it vault-1 -- vault operator unseal <KEY2>
kubectl -n vault exec -it vault-1 -- vault operator unseal <KEY3>
# Повтори для vault-2
```

---

## Quick Commands Reference

```bash
# ── Terraform ──────────────────────────────────────────────────
cd terraform

make init   ENV=<infra|stage|prod>
make plan   ENV=<infra|stage|prod>
make apply  ENV=<infra|stage|prod>
make output ENV=<infra|stage|prod>

make kubeconfig ENV=stage   # fetches kubeconfig via yc CLI
make kubeconfig ENV=prod

make fmt          # format all .tf files
make clean-all    # remove .terraform dirs
make help         # full target list

# ── Ansible ────────────────────────────────────────────────────
cd ansible

ansible-playbook playbooks/k8s-apps-stage.yml
ansible-playbook playbooks/k8s-apps-prod.yml
ansible-playbook playbooks/cnpg-databases-prod.yml
ansible-playbook playbooks/hashicorp-vault-prod.yml
ansible-playbook playbooks/gitlab-runner.yml --limit stage-runner
ansible-playbook playbooks/vpn.yml
ansible-playbook playbooks/gitlab-server.yml

# Deploy specific app only
ansible-playbook playbooks/k8s-apps-stage.yml --tags cloudnative_pg
ansible-playbook playbooks/k8s-apps-stage.yml --tags temporal
ansible-playbook playbooks/k8s-apps-stage.yml --tags vaultwarden
ansible-playbook playbooks/k8s-apps-prod.yml --tags cloudnative_pg
ansible-playbook playbooks/k8s-apps-prod.yml --tags temporal
ansible-playbook playbooks/k8s-apps-prod.yml --tags keycloak
```

---

## Teardown Order (Reverse)

```bash
# 1. Remove K8s apps (optional, TF destroy removes the whole cluster)
# ansible-playbook playbooks/k8s-apps-prod.yml --extra-vars state=absent

# 2. Prod infrastructure
cd terraform && make destroy ENV=prod

# 3. Stage infrastructure
make destroy ENV=stage

# 4. Infra (VPN + GitLab last — keep VPN up until the end)
make destroy ENV=infra
```

> ⚠️ **Warning:** Destroying infra first cuts VPN access, making it impossible to manage stage/prod remotely.

---

## Notes

| Topic | Detail |
|-------|--------|
| **State isolation** | Each environment has its own `terraform.tfstate` key in S3 |
| **Secret management** | TF passwords/tokens via `TF_VAR_*`; Ansible secrets via env vars or Ansible Vault |
| **No public IPs on workloads** | K8s API, DBs, GitLab, Vaultwarden — all private, VPN-only |
| **Preemptible nodes** | Stage uses preemptible VMs to save cost; prod uses on-demand |
| **Multi-zone HA** | Prod K8s master is regional; MDB clusters span 2 zones |
| **stage DB** | CloudNativePG + Redis k8s — deployed by Ansible, not Terraform |
| **prod DB** | CloudNativePG (2 instances) + Redis k8s — deployed by Ansible, not Terraform |
| **Loki storage** | Stage: filesystem PVC (HDD); Prod: Yandex Object Storage (S3) |
| **Vault HA** | Stage: 1 replica; Prod: 3 replicas, Raft cluster, KMS auto-unseal |
