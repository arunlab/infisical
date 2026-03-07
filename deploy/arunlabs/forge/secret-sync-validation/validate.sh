#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="forge-secrets-test"
RELEASE="forge-secrets-operator"
SECRET_FILE="${1:-${SCRIPT_DIR}/infisical-universal-auth.secret.local.yaml}"
OPERATOR_CHART="infisical-helm-charts/secrets-operator"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

wait_for_secret() {
  local namespace="$1"
  local name="$2"
  local attempts="${3:-24}"
  local sleep_seconds="${4:-5}"

  for ((i = 1; i <= attempts; i++)); do
    if kubectl get secret "${name}" -n "${namespace}" >/dev/null 2>&1; then
      return 0
    fi
    sleep "${sleep_seconds}"
  done

  echo "timed out waiting for secret/${name} in namespace ${namespace}" >&2
  return 1
}

for cmd in helm kubectl; do
  require "${cmd}"
done

if [[ ! -f "${SECRET_FILE}" ]]; then
  echo "missing credentials manifest: ${SECRET_FILE}" >&2
  echo "copy ${SCRIPT_DIR}/infisical-universal-auth.secret.example.yaml to a *.local.yaml file and set clientId/clientSecret" >&2
  exit 1
fi

kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

helm repo add infisical-helm-charts https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/ >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install "${RELEASE}" "${OPERATOR_CHART}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values "${SCRIPT_DIR}/operator-values.yaml" \
  --wait \
  --timeout 10m

kubectl apply -f "${SECRET_FILE}"
kubectl apply -f "${SCRIPT_DIR}/forge-gemini-api-key.infisicalsecret.yaml"

wait_for_secret "${NAMESPACE}" "gemini-api-key"

kubectl delete pod gemini-secret-reader -n "${NAMESPACE}" --ignore-not-found >/dev/null 2>&1 || true
kubectl apply -f "${SCRIPT_DIR}/gemini-secret-reader.pod.yaml"
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gemini-secret-reader -n "${NAMESPACE}" --timeout=90s >/dev/null

echo "Mounted secret value:"
kubectl logs -n "${NAMESPACE}" pod/gemini-secret-reader
