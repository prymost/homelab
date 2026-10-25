# Secret Management Guide

This document defines how secrets are stored, injected, and managed in this homelab.

---

## Core Principles

- **Zero Plaintext on Disk**: No `.env` files or credentials reside on host storage, in Git, or in devcontainers.
- **Bitwarden as Source of Truth**: All secrets are stored in a dedicated Bitwarden Secure Note with custom fields.
- **Process Table Safety**: Secrets are piped into `kubectl` via standard input (`stdin`). Nothing is passed via CLI flags or visible in `ps aux`.
- **GitOps Decoupling**: Git tracks only workload manifests referencing Kubernetes Secrets, never raw secret values.

---

## Agent Pre-Flight Check

Agents should inspect vault state non-interactively before running secret operations:

```bash
bw status | jq -r .status
```

- `"unauthenticated"`: Run `bw login`.
- `"locked"`: Prompt operator to unlock the vault. Agents must never attempt automated password entry.
- `"unlocked"`: Secret operations can proceed.

---

## Rotating Secrets

1. Update the custom field in Bitwarden.
2. Run the injection script:
   ```bash
   ./setup/inject_secrets_bw.sh
   ```
3. Verify cluster health: `./scripts/verify-cluster.sh`.

---

## Adding a New Secret

When deploying a container requiring a new secret:

### 1. Add Custom Field in Bitwarden
Add a custom field to the homelab Secure Note:
- **Name**: e.g., `SERVICE_API_KEY`
- **Type**: `Hidden` (passwords/tokens) or `Text`

### 2. Extend Injection Script
In [`setup/inject_secrets_bw.sh`](../setup/inject_secrets_bw.sh), extract the field and pipe to `kubectl`:
```python
new_key = fields.get("SERVICE_API_KEY")
```
Stream via stdin to create the Kubernetes Secret:
```bash
printf '%s' "$NEW_KEY" | kubectl create secret generic app-secret \
  --namespace=app-ns \
  --from-file=api-key=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Reference in Workload Manifest
In `sandbox/<app>/deployment.yaml`:
```yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: app-secret
        key: api-key
```

### 4. Apply & Commit
1. Inject the secret: `./setup/inject_secrets_bw.sh`
2. Commit the manifest and updated `setup/inject_secrets_bw.sh` to Git (no secret values are in the commit).
