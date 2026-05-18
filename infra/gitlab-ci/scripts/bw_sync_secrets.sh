#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# bw_sync_secrets.sh — Pull secrets from Vaultwarden and apply as K8s Secret
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "════════════════════════════════════════════════════════════"
echo "Starting Vaultwarden → Kubernetes Secret sync"
echo "════════════════════════════════════════════════════════════"

# ====================== Install bw CLI if missing ======================
if ! command -v bw &>/dev/null; then
  echo "==> Installing Bitwarden CLI via npm..."
  BW_VERSION="2024.2.1"
  if ! command -v npm &>/dev/null; then
    apk add --no-cache nodejs npm 2>/dev/null || apt-get install -y nodejs npm -q 2>/dev/null
  fi
  npm install -g "@bitwarden/cli@${BW_VERSION}" --quiet 2>/dev/null
  echo "✅ bw $(bw --version) installed"
fi

# ====================== TLS SETUP ======================
echo "==> Setting up TLS for Vaultwarden (self-signed)..."

if [[ -n "${BW_CA_CERT:-}" && -f "$BW_CA_CERT" ]]; then
    export NODE_EXTRA_CA_CERTS="$BW_CA_CERT"
    echo "✅ NODE_EXTRA_CA_CERTS set to: $BW_CA_CERT"
    echo "   Certificate preview:"
    head -n 5 "$BW_CA_CERT"
else
    echo "⚠️  BW_CA_CERT not set or file not found"
fi

export NODE_TLS_REJECT_UNAUTHORIZED=0
echo "⚠️  NODE_TLS_REJECT_UNAUTHORIZED=0 enabled (TLS verification disabled)"

# ====================== Add to /etc/hosts ======================
echo "==> Adding Vaultwarden to /etc/hosts..."
echo "10.10.2.12 vault.internal" | tee -a /etc/hosts >/dev/null
echo "10.30.4.13 vault-prod.internal" | tee -a /etc/hosts >/dev/null
echo "   Added: 10.10.2.12 vault.internal, 10.30.4.13 vault-prod.internal"

# ====================== Argument parsing ======================
BW_ITEM_NAME=""
K8S_SECRET_NAME=""
K8S_NAMESPACE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --item)      BW_ITEM_NAME="$2";      shift 2 ;;
    --secret)    K8S_SECRET_NAME="$2";   shift 2 ;;
    --namespace) K8S_NAMESPACE="$2";     shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$BW_ITEM_NAME" || -z "$K8S_SECRET_NAME" || -z "$K8S_NAMESPACE" ]]; then
  echo "Usage: $0 --item <bw-item> --secret <k8s-secret> --namespace <ns>"
  exit 1
fi

echo "==> Syncing item '${BW_ITEM_NAME}' → Secret '${K8S_SECRET_NAME}' (ns: ${K8S_NAMESPACE})"

# ====================== Cleanup trap ======================
cleanup() {
  echo "==> Cleanup: locking and logging out..."
  bw lock    2>/dev/null || true
  bw logout  2>/dev/null || true
  rm -rf ~/.config/Bitwarden\ CLI/ 2>/dev/null || true
}
trap cleanup EXIT

# ====================== Reset config (важно для стабильности) ======================
echo "==> Resetting Bitwarden CLI config..."
rm -rf ~/.config/Bitwarden\ CLI/
mkdir -p ~/.config/Bitwarden\ CLI/

# ====================== Configure & Login ======================
echo "==> Configuring server: ${BW_SERVER_URL}"
bw config server "$BW_SERVER_URL"

echo "==> Logging in with API key..."
bw logout >/dev/null 2>&1 || true

if ! bw login --apikey 2>&1; then
    echo "❌ Login failed"
    exit 1
fi
echo "✅ Login successful"

# ====================== Unlock ======================
echo "==> Unlocking vault..."
if ! BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw 2>/dev/null); then
    echo "❌ Unlock failed"
    exit 1
fi

export BW_SESSION
echo "✅ Vault unlocked successfully"

# ====================== Sync & Fetch ======================
echo "==> Syncing vault..."
bw sync --session "$BW_SESSION"

echo "==> Fetching item '${BW_ITEM_NAME}'..."
ITEM_JSON=$(bw get item "$BW_ITEM_NAME" --session "$BW_SESSION")

if [[ -z "$ITEM_JSON" ]]; then
  echo "❌ ERROR: Item '${BW_ITEM_NAME}' not found"
  exit 1
fi

FIELD_COUNT=$(echo "$ITEM_JSON" | jq 'if .fields then (.fields | length) else 0 end')
echo "✅ Found ${FIELD_COUNT} custom fields"

if [[ "$FIELD_COUNT" -eq 0 ]]; then
  echo "❌ ERROR: No custom fields in item"
  exit 1
fi

# ====================== Apply Secret ======================
echo "==> Applying Kubernetes Secret '${K8S_SECRET_NAME}'..."
SECRET_YAML=$(echo "$ITEM_JSON" | jq -r --arg name "$K8S_SECRET_NAME" --arg ns "$K8S_NAMESPACE" '
{
  apiVersion: "v1",
  kind: "Secret",
  metadata: {
    name: $name,
    namespace: $ns,
    labels: {
      "app.kubernetes.io/managed-by": "gitlab-ci",
      "bt6/secret-source": "vaultwarden"
    }
  },
  stringData: (
    [.fields[] | select(.value != null and .value != "" and .value != "\"\"") | {(.name): .value}]
    | add // {}
  )
} | @json' | jq '.')

kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$K8S_NAMESPACE"
echo "$SECRET_YAML" | kubectl apply -f -

echo "✅ Success: Secret '${K8S_SECRET_NAME}' synced from Vaultwarden"