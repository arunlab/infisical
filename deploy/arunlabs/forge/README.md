# Arunlabs Forge Deployment

This directory contains the `forge` cluster deployment assets for Infisical.

## Target

- Cluster: `forge`
- Namespace: `infisical`
- Exposure: cluster-internal only
- UI access: `kubectl port-forward`

## What This Uses

- Upstream Infisical standalone Helm chart from this repo
- In-cluster PostgreSQL and Redis for the incubating deployment
- Kubernetes `ClusterIP` service only

## Install

Run:

```bash
./deploy/arunlabs/forge/install.sh
```

The script:

- creates the `infisical` namespace if needed
- creates or reuses the `infisical-secrets` Secret
- generates a temporary Helm values file with the persisted DB and Redis passwords
- installs or upgrades Infisical with Helm
- configures `SITE_URL` for local port-forward access

## Access

Use:

```bash
kubectl port-forward -n infisical svc/infisical 8080:8080
```

Then open:

```text
http://localhost:8080
```

## First Login

The first user created in the UI becomes the instance admin.

## Kubernetes Secret Sync Validation

A reproducible operator-based mount test lives under `deploy/arunlabs/forge/secret-sync-validation/`.

That bundle validates the path:

```text
Infisical -> Infisical Operator -> Kubernetes Secret -> pod-mounted file
```

Run:

```bash
./deploy/arunlabs/forge/secret-sync-validation/validate.sh
```

Before running it, create the local Universal Auth credentials manifest described in:

```text
./deploy/arunlabs/forge/secret-sync-validation/README.md
```

## App Team Reference

For the reusable app workflow, including how to add a secret in Infisical, sync it into Kubernetes, mount it as a file, and use it as an env var, see:

```text
./deploy/arunlabs/forge/USING_INFISICAL_SECRETS_IN_K8S.md
```

For the compact summary of the forge-specific changes, see:

```text
./deploy/arunlabs/forge/CHANGE_SUMMARY.md
```
