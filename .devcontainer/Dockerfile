FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl \
    ca-certificates \
    docker.io \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install k3d: The tool we'll use to run K3s inside Docker
ARG K3D_VERSION="v5.6.0"
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

RUN apt-get clean && rm -rf /var/lib/apt/lists/*
