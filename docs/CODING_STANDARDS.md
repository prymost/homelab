# Coding & Architecture Standards

This is a **living document**. Every rule below is short, specific, and exists to prevent a concrete failure mode.

> **Rule for Agents & Contributors**: When you diagnose an architectural gotcha, subtle failure mode, or recurring bug during a session, add a concise **Rule** and **Why** entry to this file immediately so future agents and contributors never repeat it.

---

## 1. Kubernetes & Volume Hygiene

- **No Nested Volume Mounts**: Never mount a volume (ConfigMap, Secret, emptyDir) inside the directory path of another mounted volume (PVC).
  - *Why*: Pollutes persistent storage with ephemeral mount artifacts, breaks backup snapshots (Velero/Restic), and causes `EBUSY` unmount deadlocks during pod termination.
- **Init Containers Restricted to Idempotent Setup**: `initContainers` must only perform idempotent permission fixes (`chown`/`chmod`) or data migrations. Never create inter-volume symlinks in init containers.
  - *Why*: Creating symlinks to volumes mounted only in the app container creates dangling symlinks. On reboot, `chown -R` dereferences the broken link and fails with `ENOENT`, permanently trapping the pod in `CrashLoopBackOff`.
- **Directory Mounts for Live Config Updates**: When GitOps-managed configuration must update without pod restarts, mount the ConfigMap as a **directory**, not via `subPath`.
  - *Why*: `subPath` performs an immutable file bind-mount at container launch; Kubelet will never propagate subsequent ConfigMap changes to a subPath mount.
- **Application State vs. Read-Only Config Separation**: Never point mutable application runtime configuration paths (`$HOME/config.yaml`, database files) directly or via symlink to a `readOnly: true` mount.
  - *Why*: Modern runtimes write configs via atomic replacement (`tempfile` + `rename`). Symlinks to read-only mounts trigger unhandled `[Errno 30] Read-only file system` crashes or permanently overwrite the symlink.
- **Upstream First**: Before inventing wrapper scripts, initContainer symlinks, or container hacks to inject configurations, inspect upstream documentation and source code for native configuration layering (e.g. `HERMES_MANAGED_DIR`, `--config-dir`, `/etc/<app>/`).
  - *Why*: Upstream applications usually provide native, battle-tested system-override layers.
- **Preserve Container Image Artifacts**: Avoid mounting ConfigMaps directly over top-level system directories (like `/etc/hermes`) if the underlying container image bakes provenance or default assets into that path. Use an application-specific sub-directory (like `/etc/hermes-config`).
  - *Why*: Directory mounts mask the entire destination directory, hiding image-baked binaries and metadata files.
- **Lifecycle & Reboot Verification**: Any change modifying volume mounts or container lifecycle hooks must be verified across pod restarts (`kubectl rollout restart`), not just initial rollout.
  - *Why*: Inter-mount dependencies and file permission bugs often pass on fresh volumes but fail on the second boot.

---

## 2. Security Standards

- **Workload Hardening**: Every container must explicitly declare `securityContext`:
  - `runAsNonRoot: true` (with non-root UID/GID)
  - `allowPrivilegeEscalation: false`
  - `readOnlyRootFilesystem: true` (use explicit `emptyDir` or PVC volumes for writable caches/tmp/data)
  - `capabilities: drop: ["ALL"]`
  - `seccompProfile: { type: "RuntimeDefault" }`
  - *Why*: Defense-in-depth against container breakouts, kernel exploits, and unauthorized filesystem mutations.
- **Token Protection**: Explicitly set `automountServiceAccountToken: false` on pods and service accounts unless the workload genuinely communicates with the Kubernetes API.
  - *Why*: Eliminates lateral privilege escalation if a pod is compromised.
- **Image Pinning**: Pin all container images to specific semantic version tags or immutable SHA256 digests. Never use `:latest` or untagged images.
  - *Why*: Guarantees deterministic, reproducible deployments and protects against upstream supply-chain tampering.
- **Network Isolation**: Every application must include `network-policies/` with `default-deny.yaml` and explicit, least-privilege allow rules. Do not allow egress to the Kubernetes API (`10.43.0.1:443`) unless the workload is an authorized cluster observer.
  - *Why*: Blocks lateral movement across namespaces and prevents unauthorized external data exfiltration.
- **Secret Hygiene**: Never commit secrets or `.env` files to Git; avoid passing sensitive values as CLI arguments (visible in `ps aux`). Use Bitwarden CLI (`bw`) in-memory injection.
  - *Why*: Prevents credential leaks in git history, shell logs, and process tables.

---

## 3. Scripting & Automation (Bash & Python)

- **Strict Shell Mode**: All Bash scripts must start with `set -euo pipefail`.
  - *Why*: Fails fast on unbound variables, command failures, and masked pipeline errors.
- **Python Clean Code**: Python scripts must use type hints, follow PEP 8, and handle errors explicitly with exit codes.
  - *Why*: Ensures maintainability, testability, and automated verification compatibility.
- **In-Memory Secret Handling**: Scripts processing credentials must pipe directly in-memory and securely scrub intermediate variables without writing temporary plaintext files to disk.
  - *Why*: Prevents lingering credential artifacts on disk or in shell histories.
