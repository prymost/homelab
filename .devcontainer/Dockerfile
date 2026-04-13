FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install OS-level packages only — kubectl/helm/node are installed via devcontainer features
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl \
    ca-certificates \
    docker.io \
    nfs-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install k3d: The tool we'll use to run K3s inside Docker
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install Flux CLI
RUN curl -s https://fluxcd.io/install.sh | bash

# COPY .bash_aliases /home/vscode/.bash_aliases
