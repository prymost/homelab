# My Homelab

This repository contains everything needed to set up and run my personal homelab.

## Repository Structure

The repository is organized into two main directories:

-   `setup/`: This directory contains scripts and configurations for setting up the homelab from scratch, as well as for updating and maintaining it.
-   `content/`: This directory holds the configurations for all the services and applications running on the homelab.

## Getting Started

1.  **Explore the `setup` directory:** Start by looking at the scripts in the `setup` directory to understand how the homelab is provisioned and configured.
2.  **Check the `content` directory:** Browse the `content` directory to see the various services and applications that are deployed.

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

When a service (including the LoadBalancer) is running on the k3s cluster within the devcontainer, it's only accessible on a specific IP address from the main devcontainer host. To access it from your browser, you need to forward the port to `localhost`.

You can achieve this using the following command:

```bash
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>
```
