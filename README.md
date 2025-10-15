# My Homelab

This repository contains everything needed to set up and run my personal homelab.

## Repository Structure

The repository is organized as follows:

-   `.github/`: Contains GitHub Actions workflows for CI/CD, such as automated security scanning.
-   `setup/`: Contains scripts and configurations for initial server setup.
-   `clusters/homelab/`: Holds the FluxCD manifests that define the cluster's state. It uses Kustomize to reference configurations from the `sandbox` directory.
-   `sandbox/`: Contains the raw configuration files (e.g., Helm `values.yaml`) for applications, which are then applied to the cluster from the `clusters` directory.

## Getting Started

1.  **Explore the `setup` directory:** Start by looking at the scripts in the `setup` directory to understand how the homelab is provisioned and configured.
    - debian_bootstrap.sh: Initial setup script for Debian-based systems.
2.  **Check the `clusters/homelab` directory:** Browse the `clusters/homelab` directory to see the various services and applications that are deployed.
    - mealie/: Configuration for the Mealie recipe manager.
    - monitoring/: Configuration for the monitoring stack (Prometheus, Grafana, Alertmanager).

## Development Environment

This repository is set up to be used with a devcontainer. The devcontainer provides a consistent and isolated development environment with all the necessary tools and dependencies pre-installed.

To get started with the devcontainer, you need to have the following installed:

-   [Visual Studio Code](https://code.visualstudio.com/)
-   [Docker Engine](https://docs.docker.com/engine/)
-   [Remote - Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension for VS Code

Once you have these installed, you can open this repository in the devcontainer by clicking the "Reopen in Container" button in the bottom right corner of VS Code.

### Devcontainer Features

The devcontainer is configured with the following features:

-   **K3s:** A lightweight Kubernetes distribution that runs in a Docker container.
-   **Docker-in-Docker:** Allows you to use Docker commands inside the devcontainer. Needed for k3s to run properly.
-   **Kubectl:** The command-line tool for interacting with Kubernetes clusters.

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
