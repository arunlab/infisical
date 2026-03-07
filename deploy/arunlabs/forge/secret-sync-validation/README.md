# Kubernetes Secret Sync Validation

This bundle proves the in-cluster path:

`Infisical -> Infisical Operator -> native Kubernetes Secret -> pod-mounted file`

It is intentionally namespace-scoped so the operator only watches `forge-secrets-test`.

## What Was Validated

Live validation on `forge` succeeded on `2026-03-07`.

- Operator release: `forge-secrets-operator`
- Operator namespace: `forge-secrets-test`
- Infisical project: `Forge Secrets Validation`
- Infisical project ID: `c4d26591-3a04-49bc-a318-7478f36cec94`
- Environment slug: `dev`
- Secret synced from Infisical: `GEMINI_API_KEY`
- Managed Kubernetes Secret: `gemini-api-key`
- Consumer pod: `gemini-secret-reader`

Observed mount output:

```text
gemini-test-key-validation-2026-03-07
```

## Files

- `namespace.yaml`: validation namespace
- `operator-values.yaml`: namespace-scoped operator values
- `infisical-universal-auth.secret.example.yaml`: example credentials secret for Universal Auth
- `forge-gemini-api-key.infisicalsecret.yaml`: CRD that syncs the Infisical secret into Kubernetes
- `gemini-secret-reader.pod.yaml`: pod that mounts the synced Kubernetes Secret as a file
- `validate.sh`: idempotent end-to-end validation runner

## Prerequisites

- `kubectl` pointed at `forge`
- `helm` installed locally
- Infisical already deployed in namespace `infisical`
- A valid Universal Auth client for the `forge-k8s-operator-test` identity in project `Forge Secrets Validation`

## Create the Local Credentials Manifest

Do not commit real client credentials. Create a local file from the example:

```bash
cp ./deploy/arunlabs/forge/secret-sync-validation/infisical-universal-auth.secret.example.yaml \
  ./deploy/arunlabs/forge/secret-sync-validation/infisical-universal-auth.secret.local.yaml
```

Edit `clientId` and `clientSecret` in the local file.

The `.gitignore` in this directory ignores `*.local.yaml`.

## Run the Validation

```bash
./deploy/arunlabs/forge/secret-sync-validation/validate.sh
```

To use a different credentials file:

```bash
./deploy/arunlabs/forge/secret-sync-validation/validate.sh /absolute/path/to/credentials.yaml
```

## Manual Verification

Check the operator and CRD:

```bash
kubectl get pods -n forge-secrets-test
kubectl get infisicalsecret -n forge-secrets-test
kubectl get secret gemini-api-key -n forge-secrets-test
```

Re-run the consumer pod and print the mounted file:

```bash
kubectl delete pod gemini-secret-reader -n forge-secrets-test --ignore-not-found
kubectl apply -f ./deploy/arunlabs/forge/secret-sync-validation/gemini-secret-reader.pod.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/gemini-secret-reader -n forge-secrets-test --timeout=90s
kubectl logs -n forge-secrets-test pod/gemini-secret-reader
```
