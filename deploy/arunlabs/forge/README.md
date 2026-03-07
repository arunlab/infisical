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
