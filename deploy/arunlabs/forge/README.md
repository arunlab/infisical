# Arunlabs Forge Deployment

This directory contains the `forge` cluster deployment assets for Infisical.

## Target

- Cluster: `forge`
- Namespace: `infisical`
- Hostname: `vault.arunlabs.com`
- TLS termination: `istio-system/arunlabs-public-gateway`

## What This Uses

- Upstream Infisical standalone Helm chart from this repo
- In-cluster PostgreSQL and Redis for the incubating deployment
- Existing Istio ingress gateway and wildcard certificate for `*.arunlabs.com`

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
- applies the Istio `VirtualService`

## DNS

Create a LAN DNS record:

- `vault.arunlabs.com -> 172.16.0.191`

That points the hostname at the forge Istio ingress gateway while still using the public wildcard certificate.

## First Login

The first user created in the UI becomes the instance admin.
