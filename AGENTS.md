# AGENTS.md

## Project Overview
This repository contains the **Infrastructure-as-Code (IaC)** and configuration for a personal homelab, managed via a **GitOps** workflow. It automates the deployment and management of various services on a Kubernetes cluster.

### Core Technologies
- **Kubernetes (K3s):** Lightweight Kubernetes distribution used for both production and development.
- **FluxCD:** The GitOps controller that synchronizes the cluster state with this repository.
- **Kustomize:** Orchestrates and patches Kubernetes manifests.
- **Helm:** Manages application deployments via Flux `HelmRelease` resources.
- **Traefik:** Acts as the Ingress controller and reverse proxy.
- **Monitoring Stack:** Prometheus, Grafana, and Alertmanager for observability.
- **Security:** Trivy for vulnerability scanning of images and manifests.
- **Applications:** Home Assistant (smart home), Minecraft server, and NFS provisioner for storage.

---

## Directory Structure
- **`clusters/homelab/`**: Defines the "live" state of the production cluster. It uses Kustomize to include and patch applications defined in the `sandbox/` directory.
- **`sandbox/`**: Contains the base configurations and Helm values for all applications.
- **`ansible/`**: Automated infrastructure bootstrapping and configuration.
    - `homelab.yml`: Main playbook orchestrating all machines.
    - `roles/`: Modular configuration for `common` OS settings, `k3s` nodes, and `kiosk` PC.
- **`setup/`**: Legacy infrastructure bootstrapping scripts.
- **`home_assistant/`**: Application-specific configuration files (e.g., YAML dashboards).
- **`.devcontainer/`**: A complete local development environment with K3s-in-Docker and Ansible.

---

## Key Workflows

### 1. Initial Machine Setup (Ansible)
To prepare a new node or apply configuration changes across the homelab:
1. Ensure your SSH key is authorized on the target machine.
2. Update `ansible/inventory/hosts.yml` with the machine details.
3. Run the playbook:
   ```bash
   cd ansible
   ansible-playbook homelab.yml
   ```
*Note: This process is declarative. Running it multiple times is safe and only applies necessary changes.*

### 2. Secret Management
**NEVER commit secrets to Git.** This project uses a manual injection strategy:
1. Copy `.env.sample` to `.env`.
2. Fill in the required variables (e.g., `EMAIL_PASS`).
3. Run the injection script:
   ```bash
   ./setup/create_secrets.sh
   ```
This creates the necessary Kubernetes secrets (e.g., `robusta-secret-values`) in the appropriate namespaces.

### 3. Development and Testing
Use the provided **Devcontainer** for a safe testing environment. It includes a local K3s cluster.
- **Port Forwarding**: Access services via `kubectl port-forward svc/<name> <port>:<port> -n <namespace>`.
- **Ingress Testing**: Forward Traefik (port 8080) and use `curl -H "Host: <hostname>"` to test routing.

### 4. Deploying Changes
Changes are automatically picked up by FluxCD once pushed to the `main` branch.
- To add a new app: Define it in `sandbox/`, then add a reference in `clusters/homelab/kustomization.yaml`.

---

## Development Conventions
- **Security First**: Security is the top priority for this Kubernetes cluster. All workloads, manifests, and configurations must be hardened by default to prevent rogue containers and unauthorized access:
  - **Workload Hardening**: Every pod/container must define an explicit `securityContext`:
    - `runAsNonRoot: true` (with non-root UID/GID)
    - `allowPrivilegeEscalation: false`
    - `readOnlyRootFilesystem: true` (use explicit `emptyDir` or PVC volumes for writable caches/tmp/data)
    - `capabilities: drop: ["ALL"]` (only add specific Linux capabilities if demonstrably essential)
    - `seccompProfile: { type: "RuntimeDefault" }`
  - **Token Protection**: Explicitly set `automountServiceAccountToken: false` on pods and service accounts unless the workload genuinely communicates with the Kubernetes API.
  - **Image Pinning**: Always pin container images to specific semantic version tags or immutable digests. Never use `:latest` or untagged images.
  - **Network Isolation**: Every application in `sandbox/` must include a `network-policies/` directory with `default-deny.yaml` (blocking all ingress and egress) and explicit, least-privilege allow rules. Do not allow egress to the Kubernetes API server (`10.43.0.1:443`) unless the application is a cluster controller.
  - **Secret Hygiene**: Never commit secrets or `.env` files to Git; avoid passing sensitive values as command-line arguments (visible in `ps aux`).
- **Operational Continuity & Non-Breaking Verification**:
  - Security hardening must never compromise legitimate homelab functionality.
  - Whenever security policies or network restrictions are introduced or modified, explicitly test and verify end-to-end functionality:
    - Minecraft server connectivity from local computers/laptops (port 25565 TCP).
    - Home Assistant dashboard access (`ha.lan`), integrations, and local smart device discovery.
    - NFS persistent storage mounts and write permissions.
    - Monitoring and alert forwarding (Robusta/Prometheus).
  - Never over-restrict network policies blindly. If uncertain whether a port or network path is required by an integration, pause and confirm with Boris before applying.
- **GitOps First**: All cluster changes must be made through Git commits. Avoid `kubectl edit` on live resources.
- **Separation of Concerns**: Keep base manifests/values in `sandbox/` and cluster-specific overlays in `clusters/`.
- **Documentation**: Keep `CHANGELOG.md` updated and use `TODOs.md` for task tracking.

---

## Common Commands
- **Switch Context**:
  - `kubectl config use-context homelab` (Production)
  - `kubectl config use-context k3d-my-dev-cluster` (Local Dev)
- **List Contexts**: `kubectl config get-contexts`
- **Check Flux Sync Status**: `flux get kustomizations`
- **Manual Flux Reconcile**: `flux reconcile kustomization flux-system --with-source`
- **View Logs**: `kubectl logs -f -l app=<app-name> -n <namespace>`
- **Check Trivy Scans**: `kubectl get vulnerabilityreports -A`
