# Forge Change Summary

This is the short summary of the recent `forge` Infisical work.

## Current State

- Infisical is deployed in namespace `infisical`
- Exposure is cluster-local only
- UI access is through `kubectl port-forward`
- PostgreSQL and Redis run in-cluster for this incubating setup

## Secret Sync Work

- Added a namespace-scoped operator validation flow under `secret-sync-validation/`
- Verified the path `Infisical -> Kubernetes Secret -> pod-mounted file`
- Confirmed the mounted validation value from the consumer pod on `2026-03-07`

## Reference Docs

- Added a reusable app-team guide for adding secrets, syncing them, and mounting them in pods
- Kept the validation bundle separate from the general usage guide

## Git Safety

- Existing Husky `pre-commit` hook scans staged changes for secrets
- Added a Husky `pre-push` hook to scan the commit range being pushed
