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
- **`setup/`**: Infrastructure bootstrapping scripts.
    - `debian_bootstrap.sh`: Prepares a fresh Debian install (SSH, static IP, lid sleep, core packages).
    - `create_secrets.sh`: Helper script to inject Kubernetes secrets from a local `.env` file.
- **`home_assistant/`**: Application-specific configuration files (e.g., YAML dashboards).
- **`.devcontainer/`**: A complete local development environment with K3s-in-Docker.

---

## Key Workflows

### 1. Initial Server Setup
To prepare a new node for the homelab:
```bash
./setup/debian_bootstrap.sh
```
*Note: This script is interactive and requires sudo.*

### 2. Secret Management
**NEVER commit secrets to Git.** This project uses a manual injection strategy:
1. Copy `.env.sample` to `.env`.
2. Fill in the required variables (e.g., `EMAIL_PASS`).
3. Run the injection script:
   ```bash
   ./setup/create_secrets.sh
   ```
This creates generic Kubernetes secrets (e.g., `alertmanager-email-creds`) in the appropriate namespaces.

### 3. Development and Testing
Use the provided **Devcontainer** for a safe testing environment. It includes a local K3s cluster.
- **Port Forwarding**: Access services via `kubectl port-forward svc/<name> <port>:<port> -n <namespace>`.
- **Ingress Testing**: Forward Traefik (port 8080) and use `curl -H "Host: <hostname>"` to test routing.

### 4. Deploying Changes
Changes are automatically picked up by FluxCD once pushed to the `main` branch.
- To add a new app: Define it in `sandbox/`, then add a reference in `clusters/homelab/kustomization.yaml`.

---

## Development Conventions
- **GitOps First**: All cluster changes must be made through Git commits. Avoid `kubectl edit` on live resources.
- **Separation of Concerns**: Keep base manifests/values in `sandbox/` and cluster-specific overlays in `clusters/`.
- **Network Security**: Every application in `sandbox/` should include a `network-policies/` directory with at least a `default-deny.yaml` and necessary allow rules.
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
