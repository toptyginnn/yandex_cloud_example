#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# deploy.sh — Sync secrets from Vaultwarden and deploy app via Helm
#
# Usage:
#   bash deploy.sh \
#     --app       backend \
#     --env       stage \
#     --image     cr.yandex/<id>/backend:stage-abc1234 \
#     --chart     /tmp/infra/gitlab-ci/helm/backend \
#     --values    /tmp/infra/gitlab-ci/helm/backend/values-stage.yaml \
#     --namespace backend-stage \
#     --timeout   10m
#
# Required env vars (GitLab CI masked variables):
#   BW_SERVER_URL, BW_CLIENTID, BW_CLIENTSECRET, BW_PASSWORD
#   KUBECONFIG (must be set before calling this script)
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
APP_NAME=""
ENV_NAME=""
IMAGE=""
CHART_PATH=""
VALUES_FILE=""
NAMESPACE=""
TIMEOUT="10m"

while [[ $# -gt 0 ]]; do
  case $1 in
    --app)       APP_NAME="$2";    shift 2 ;;
    --env)       ENV_NAME="$2";    shift 2 ;;
    --image)     IMAGE="$2";       shift 2 ;;
    --chart)     CHART_PATH="$2";  shift 2 ;;
    --values)    VALUES_FILE="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2";   shift 2 ;;
    --timeout)   TIMEOUT="$2";     shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

for var in APP_NAME ENV_NAME IMAGE CHART_PATH VALUES_FILE NAMESPACE; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: --${var,,} is required"
    exit 1
  fi
done

HELM_RELEASE="${APP_NAME}-${ENV_NAME}"
BW_ITEM_NAME="bt6-${APP_NAME}-${ENV_NAME}"
K8S_SECRET_NAME="${APP_NAME}-secrets"
SCRIPTS_DIR="$(dirname "$0")"
HELM_SECRET_ARGS=""

echo "════════════════════════════════════════════════════════════"
echo " Deploying ${HELM_RELEASE}"
echo " Image:     ${IMAGE}"
echo " Namespace: ${NAMESPACE}"
echo " Chart:     ${CHART_PATH}"
echo " Env:       ${ENV_NAME}"
echo "════════════════════════════════════════════════════════════"

# ── Step 1: Sync secrets from Vaultwarden (skip if no BW_SERVER_URL) ─────────
echo ""
echo "── Step 1: Secrets from Vaultwarden ────────────────────────"

# Prod использует отдельные Vaultwarden credentials если заданы
if [[ "$ENV_NAME" == "prod" ]]; then
  [[ -n "${BW_SERVER_URL_PROD:-}" ]]  && export BW_SERVER_URL="${BW_SERVER_URL_PROD}"
  [[ -n "${BW_CLIENTID_PROD:-}" ]]    && export BW_CLIENTID="${BW_CLIENTID_PROD}"
  [[ -n "${BW_CLIENTSECRET_PROD:-}" ]] && export BW_CLIENTSECRET="${BW_CLIENTSECRET_PROD}"
  [[ -n "${BW_PASSWORD_PROD:-}" ]]    && export BW_PASSWORD="${BW_PASSWORD_PROD}"
  echo "==> Using prod Vaultwarden: ${BW_SERVER_URL}"
fi

if [[ -n "${BW_SERVER_URL:-}" ]]; then
  bash "${SCRIPTS_DIR}/bw_sync_secrets.sh" \
    --item      "$BW_ITEM_NAME" \
    --secret    "$K8S_SECRET_NAME" \
    --namespace "$NAMESPACE"
  HELM_SECRET_ARGS="--set secretName=${K8S_SECRET_NAME}"
else
  echo "⚠️  BW_SERVER_URL not set — skipping Vaultwarden sync"
fi

# ── Step 2: Helm upgrade --install ───────────────────────────────────────────
echo ""
echo "── Step 2: Helm deploy ──────────────────────────────────────"

IMAGE_REPO="${IMAGE%:*}"
IMAGE_TAG="${IMAGE#*:}"

helm upgrade --install "$HELM_RELEASE" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "$VALUES_FILE" \
  --set "image.repository=${IMAGE_REPO}" \
  --set "image.tag=${IMAGE_TAG}" \
  ${HELM_SECRET_ARGS} \
  --atomic \
  --timeout "$TIMEOUT" \
  --wait

echo ""
echo "── Step 3: Verify rollout ───────────────────────────────────"
kubectl rollout status deployment \
  -l "app.kubernetes.io/instance=${HELM_RELEASE}" \
  --namespace "$NAMESPACE" \
  --timeout "$TIMEOUT"

echo ""
echo "✓ Deployment of ${HELM_RELEASE} completed successfully"
