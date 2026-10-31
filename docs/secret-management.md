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
3. Restart affected workloads to load rotated secrets:
   ```bash
   kubectl rollout restart deployment/hermes-agent -n hermes-agent
   ```
4. Verify cluster health: `./scripts/verify-cluster.sh`.

---

## Adding a New Secret

When deploying a container requiring a new secret:

### 1. Add Custom Field in Bitwarden
Add a custom field to the homelab Secure Note:
- **Name**: e.g., `SERVICE_API_KEY`
- **Type**: `Hidden` (passwords/tokens) or `Text`

### 2. Extend Secret Renderer
In [`setup/render_secrets.py`](../setup/render_secrets.py), map the field into the target secret manifest:
```python
def render_myservice(fields: Dict[str, str]) -> List[Dict[str, Any]]:
    api_key = fields.get("SERVICE_API_KEY")
    if not api_key:
        return []
    return [build_secret("myservice-secrets", "myservice", {"API_KEY": api_key})]
```

### 3. Reference in Workload Manifest
In `sandbox/<app>/deployment.yaml`:
```yaml
env:
  - name: SERVICE_API_KEY
    valueFrom:
      secretKeyRef:
        name: myservice-secrets
        key: API_KEY
```

### 4. Apply & Commit
1. Inject the secret: `./setup/inject_secrets_bw.sh`
2. Commit the manifest and updated `setup/render_secrets.py` to Git (no secret values are in the commit).

---

## Secret Field Reference

### Hermes Agent (`hermes-agent-secrets`)

| Bitwarden Field Name | Kubernetes Secret Key | Required / Optional | Description |
| :--- | :--- | :--- | :--- |
| `HERMES_TELEGRAM_BOT_TOKEN` | `TELEGRAM_BOT_TOKEN` | Required | Bot authentication token from BotFather |
| `HERMES_TELEGRAM_ALLOWED_USERS` | `TELEGRAM_ALLOWED_USERS` | Required | Authorized Telegram user ID(s) |
| `HERMES_OPENAI_API_KEY` | `OPENAI_API_KEY` | Required | Primary inference provider API key |
| `HERMES_OPENAI_BASE_URL` | `OPENAI_BASE_URL` | Optional | Custom inference base URL |
| `HERMES_TAVILY_API_KEY` | `TAVILY_API_KEY` | Optional | Search tool API key |
| `HERMES_GITHUB_APP_ID` | `GITHUB_APP_ID` | Optional | GitHub App ID for Git credential helper |
| `HERMES_GITHUB_INSTALLATION_ID` | `GITHUB_INSTALLATION_ID` | Optional | GitHub App installation ID |
| `HERMES_GITHUB_APP_PRIVATE_KEY` | `GITHUB_APP_PRIVATE_KEY` | Optional | GitHub App private key PEM |
| `HERMES_LINQ_BUILDING_ID` | `LINQ_BUILDING_ID` | Optional (Atomic) | LINQ Connect Building GUID for school lunch automation |
| `HERMES_LINQ_DISTRICT_ID` | `LINQ_DISTRICT_ID` | Optional (Atomic) | LINQ Connect District GUID for school lunch automation |

### Hermes Google Calendar (`hermes-agent-gcal-secrets`)

| Bitwarden Field Name | Kubernetes Secret Key | Required / Optional | Description |
| :--- | :--- | :--- | :--- |
| `HERMES_GOOGLE_CLIENT_SECRET` | `google-client-secret.json` | Optional (Atomic) | Google OAuth 2.0 Desktop client secret JSON |
| `HERMES_GOOGLE_TOKEN` | `google-token.json` | Optional (Atomic) | Google OAuth 2.0 authorized user refresh token JSON (scoped to `calendar.events`) |
