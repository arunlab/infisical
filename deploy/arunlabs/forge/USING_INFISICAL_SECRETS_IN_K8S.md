# Using Infisical Secrets In Kubernetes

This is the reference workflow for app teams on `forge`.

The operating model is:

`Infisical -> Infisical Operator -> native Kubernetes Secret -> app pod`

Use this guide when you want to:

- add a secret to Infisical
- sync it into Kubernetes
- mount it into a pod as a file
- or expose it to the container as an environment variable

## Prerequisites

- `kubectl` points to the `forge` cluster
- Infisical is running in namespace `infisical`
- The Infisical Operator is installed for the target namespace
- You have a project in Infisical and a machine identity with read access to that project

## 1. Open Infisical

Port-forward the UI locally:

```bash
kubectl port-forward -n infisical svc/infisical 8080:8080
```

Open:

```text
http://localhost:8080
```

## 2. Add The Secret In Infisical

Inside the Infisical UI:

1. Open the target project.
2. Choose the correct environment such as `dev` or `prod`.
3. Add the secret key and value.

Example:

- Key: `DATABASE_URL`
- Value: `postgres://app:password@postgres:5432/app`

## 3. Create The Universal Auth Credentials Secret In Kubernetes

The operator uses a machine identity to read from Infisical. Store that identity's Universal Auth credentials in the target namespace.

Do not commit real credentials to Git.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: infisical-universal-auth
  namespace: your-namespace
type: Opaque
stringData:
  clientId: <machine-identity-client-id>
  clientSecret: <machine-identity-client-secret>
```

Apply it:

```bash
kubectl apply -f infisical-universal-auth.secret.yaml
```

## 4. Create The `InfisicalSecret` Resource

This CRD tells the operator which Infisical secret(s) to fetch and which Kubernetes `Secret` to manage.

### Single secret sync

```yaml
apiVersion: secrets.infisical.com/v1alpha1
kind: InfisicalSecret
metadata:
  name: app-database-url
  namespace: your-namespace
spec:
  hostAPI: http://infisical.infisical.svc.cluster.local:8080/api
  syncConfig:
    resyncInterval: 60s
  authentication:
    universalAuth:
      credentialsRef:
        secretName: infisical-universal-auth
        secretNamespace: your-namespace
      secretsScope:
        projectId: <infisical-project-id>
        envSlug: prod
        secretsPath: /
        secretName: DATABASE_URL
  managedKubeSecretReferences:
    - secretName: app-secrets
      secretNamespace: your-namespace
      creationPolicy: Owner
      secretType: Opaque
```

Apply it:

```bash
kubectl apply -f app-database-url.infisicalsecret.yaml
```

### Sync all secrets from a path

If you want one managed Kubernetes `Secret` containing everything at `/`, remove `secretName`.

```yaml
secretsScope:
  projectId: <infisical-project-id>
  envSlug: prod
  secretsPath: /
```

## 5. Verify The Managed Kubernetes Secret Exists

```bash
kubectl get infisicalsecret -n your-namespace
kubectl get secret app-secrets -n your-namespace
kubectl get secret app-secrets -n your-namespace -o jsonpath='{.data}' | jq
```

## 6. Mount The Secret As A File

Use this pattern for API keys, JSON blobs, certificates, and other file-oriented secrets.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-secret-reader
  namespace: your-namespace
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - cat /mnt/secrets/DATABASE_URL && echo
      volumeMounts:
        - name: app-secrets
          mountPath: /mnt/secrets
          readOnly: true
  volumes:
    - name: app-secrets
      secret:
        secretName: app-secrets
```

Apply and inspect:

```bash
kubectl apply -f app-secret-reader.pod.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/app-secret-reader -n your-namespace --timeout=90s
kubectl logs -n your-namespace pod/app-secret-reader
```

## 7. Use The Secret As An Environment Variable

Use this pattern when the application already expects env vars.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: your-namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: ghcr.io/example/my-app:latest
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: DATABASE_URL
```

Important:

- mounted secret files can be refreshed when the Kubernetes `Secret` changes
- environment variables are fixed at container start time
- if a synced secret changes and your app reads it from env vars, restart or roll out the workload

Example restart:

```bash
kubectl rollout restart deployment/my-app -n your-namespace
```

## 8. Namespace-Scoped Operator Install

If the target namespace does not already have an operator release, install one with scoped RBAC.

```yaml
scopedNamespaces:
  - your-namespace
scopedRBAC: true
```

```bash
helm repo add infisical-helm-charts https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/
helm repo update
helm upgrade --install your-secrets-operator infisical-helm-charts/secrets-operator \
  --namespace your-namespace \
  --create-namespace \
  --values operator-values.yaml
```

## Recommended Pattern

For normal app usage on `forge`:

- store secrets in Infisical per project/environment
- sync them into one Kubernetes `Secret` per app or per bounded app surface
- mount files for certificates, JSON, and multiline data
- use env vars only when the application already requires them
- keep Universal Auth client credentials out of Git

## Reference Implementation

The working validation example in this repo is here:

- `deploy/arunlabs/forge/secret-sync-validation/README.md`
- `deploy/arunlabs/forge/secret-sync-validation/validate.sh`
- `deploy/arunlabs/forge/secret-sync-validation/forge-gemini-api-key.infisicalsecret.yaml`

That bundle was validated successfully on `forge` on `2026-03-07`.
