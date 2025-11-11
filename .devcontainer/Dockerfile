FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl \
    gpg \
    ca-certificates \
    apt-transport-https \
    docker.io \
    nfs-common \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    && apt-get update \
    && apt-get install helm

# Install kubeseal
ARG KUBESEAL_VERSION="0.26.1"
RUN curl -sL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" | tar -xz -C /usr/local/bin kubeseal

# Install k3d: The tool we'll use to run K3s inside Docker
# ARG K3D_VERSION="v5.6.0"
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

COPY .bash_aliases /home/vscode/.bash_aliases
