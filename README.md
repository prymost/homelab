# My Homelab

This repository contains everything needed to set up and run my personal homelab.

## Repository Structure

The repository is organized as follows:

-   `.github/`: Contains GitHub Actions workflows for CI/CD, such as automated security scanning.
-   `ansible/`: Ansible playbooks and roles for automated OS-level configuration and K3s bootstrapping.
-   `scripts/`: Verification and autonomous rollback automation tools (`verify-cluster.sh`, `rollback.sh`).
-   `setup/`: Contains legacy scripts and configurations for initial server setup.
-   `clusters/homelab/`: Holds the FluxCD manifests that define the cluster's state. It uses Kustomize to reference configurations from the `sandbox` directory.
-   `sandbox/`: Contains the raw configuration files (e.g., Helm `values.yaml`) for applications, which are then applied to the cluster from the `clusters` directory.

## Getting Started

1.  **Explore the `setup` directory:** Start by looking at the scripts in the `setup` directory to understand how the homelab is provisioned and configured.
2.  **Check the `clusters/homelab` directory:** Browse the `clusters/homelab` directory to see the various services and applications that are deployed.
    - flux-system/: FluxCD's own manifests for managing the cluster.
    - kube-system/: Core Kubernetes system configurations, including Traefik.
    - home-assistant/: Smart home automation platform and dashboard.
    - minecraft/: Configuration for the Minecraft server.
    - monitoring/: Robusta monitoring stack for automated Kubernetes alert dispatch and event enrichment.
    - nfs-provisioner/: Dynamic persistent volume provisioner backed by NAS NFS storage.
    - trivy/: Configuration for Trivy vulnerability scanner.

## Development Environment

This repository is set up to be used with a devcontainer. The devcontainer provides a consistent and isolated development environment with all the necessary tools and dependencies pre-installed.

To get started with the devcontainer, you need to have the following installed:

-   [Visual Studio Code](https://code.visualstudio.com/)
-   [Docker Engine](https://docs.docker.com/engine/)
-   [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension for VS Code

Once you have these installed, you can open this repository in the devcontainer by clicking the "Reopen in Container" button in the bottom right corner of VS Code.

### Devcontainer Features

The devcontainer is configured with the following features:

-   **Ansible:** For automated infrastructure management and provisioning.
-   **K3s:** A lightweight Kubernetes distribution that runs in a Docker container.
-   **Docker-in-Docker:** Allows you to use Docker commands inside the devcontainer. Needed for k3s to run properly.
-   **Kubectl:** The command-line tool for interacting with Kubernetes clusters.

### Cluster Management

The devcontainer has access to both the local development cluster (`k3d-my-dev-cluster`) and the production homelab cluster (`homelab`). To switch between them:

-   **To homelab (Production):** `kubectl config use-context homelab`
-   **To k3d (Local Dev):** `kubectl config use-context k3d-my-dev-cluster`

To list all available contexts: `kubectl config get-contexts`

## Secret Management

Secrets are injected on-demand into Kubernetes memory using the Bitwarden CLI (`./setup/inject_secrets_bw.sh`) with zero plaintext storage on disk or in Git. For usage, rotation, and adding new secrets, refer to [docs/secret-management.md](docs/secret-management.md).

## Tips

### Port Forwarding

When a service (including the LoadBalancer) is running on the k3s cluster within the devcontainer, it's only accessible on a specific IP address from the main devcontainer host. To access it from your browser, you need to forward the port to `localhost`.

You can achieve this using the following command:

```bash
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>
```

### Testing Ingress
If you have set up ingress for a service in the devcontainer, you can test it with the following command after port forwarding traefik to localhost:8080

```bash
curl -I -H "Host: <dedicated-hostname>" http://localhost:8080
```

### Cluster Health Verification
To verify the end-to-end health of all cluster workloads, storage mounts, network policies, and FluxCD GitOps synchronization:

```bash
# Run 21 automated cluster health checks
./scripts/verify-cluster.sh

# Trigger Flux sync and wait for latest commit to reconcile before checking
./scripts/verify-cluster.sh --wait-sync
```
