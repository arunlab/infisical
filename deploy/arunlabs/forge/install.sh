#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CHART_DIR="${REPO_ROOT}/helm-charts/infisical-standalone-postgres"
NAMESPACE="infisical"
RELEASE="infisical"
SECRETS_NAME="infisical-secrets"
SITE_URL="https://vault.arunlabs.com"
RUNTIME_VALUES="${SCRIPT_DIR}/runtime-values.yaml"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

get_secret_value() {
  local key="$1"

  kubectl -n "${NAMESPACE}" get secret "${SECRETS_NAME}" -o json 2>/dev/null | jq -r --arg key "${key}" '.data[$key] // empty | @base64d' || true
}

for cmd in helm jq kubectl openssl; do
  require "${cmd}"
done

kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

kubectl patch svc istio-ingressgateway \
  -n istio-system \
  --type merge \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'

AUTH_SECRET="$(get_secret_value AUTH_SECRET)"
ENCRYPTION_KEY="$(get_secret_value ENCRYPTION_KEY)"
POSTGRES_PASSWORD="$(get_secret_value POSTGRES_PASSWORD)"
REDIS_PASSWORD="$(get_secret_value REDIS_PASSWORD)"
TELEMETRY_ENABLED="$(get_secret_value TELEMETRY_ENABLED)"

AUTH_SECRET="${AUTH_SECRET:-$(openssl rand -base64 32 | tr -d '\n')}"
ENCRYPTION_KEY="${ENCRYPTION_KEY:-$(openssl rand -hex 16)}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -hex 16)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -hex 16)}"
TELEMETRY_ENABLED="${TELEMETRY_ENABLED:-false}"

kubectl -n "${NAMESPACE}" create secret generic "${SECRETS_NAME}" \
  --from-literal=AUTH_SECRET="${AUTH_SECRET}" \
  --from-literal=ENCRYPTION_KEY="${ENCRYPTION_KEY}" \
  --from-literal=SITE_URL="${SITE_URL}" \
  --from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --from-literal=REDIS_PASSWORD="${REDIS_PASSWORD}" \
  --from-literal=TELEMETRY_ENABLED="${TELEMETRY_ENABLED}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null

cleanup() {
  rm -f "${RUNTIME_VALUES}"
}
trap cleanup EXIT

cat > "${RUNTIME_VALUES}" <<EOF
infisical:
  kubeSecretRef: ${SECRETS_NAME}

postgresql:
  auth:
    password: ${POSTGRES_PASSWORD}

redis:
  auth:
    password: ${REDIS_PASSWORD}
EOF

helm dependency build "${CHART_DIR}"

helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --values "${SCRIPT_DIR}/values.base.yaml" \
  --values "${RUNTIME_VALUES}" \
  --wait \
  --timeout 20m

kubectl apply -f "${SCRIPT_DIR}/virtualservice.yaml"
kubectl apply -f "${SCRIPT_DIR}/authorization-policy.yaml"
kubectl rollout status deployment/infisical -n "${NAMESPACE}" --timeout=5m

kubectl get pods,svc,virtualservice -n "${NAMESPACE}"
