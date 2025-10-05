## 🛠️ Homelab Setup: Debian + K3s + Flux (To-Do List)

```mermaid
graph TD
    subgraph Development Environment
        DEV[VS Code DevContainer]
        TERMINAL(Terminal/Shell)
        K3D(K3s Cluster 'k3d')
        FLUX_CLI[Flux CLI]
        HELM_CLI[Helm CLI]
    end

    subgraph Source of Truth
        GIT[GitHub Repository]
    end

    subgraph Production Homelab
        K3S_CP{K3s Server 'Laptop 1'}
        K3S_WK[K3s Agent 'Laptop 2']
        FLUX_C{Flux Controllers}
        APP[Prometheus Stack]
    end

    DEV -- 1. Test Config/Manifests --> K3D
    TERMINAL -- Alias/Export (Bashrc) --> DEV
    FLUX_CLI -- 2. Bootstrap/Install --> K3S_CP
    HELM_CLI -- Test OCI/Helm Install --> K3D

    DEV -- 3. Commit & Push YAML --> GIT

    K3S_CP -- 4. Kubeconfig/API --> K3S_WK
    K3S_CP -- Kubeconfig/API --> K3S_CP

    GIT -- 5. Watch & Pull Changes --> FLUX_C
    FLUX_C -- 6. Reconcile/Apply --> K3S_CP
    FLUX_C -- 6. Reconcile/Apply --> K3S_WK
    K3S_CP -- 7. Resources/Pods --> APP

    %% Styles with black text for readability

    %% Development Environment (Light Blue/Teal)
    style DEV fill:#C1E7FF,stroke:#0077B6,color:#000
    style TERMINAL fill:#C1E7FF,stroke:#0077B6,color:#000
    style K3D fill:#C1E7FF,stroke:#0077B6,color:#000
    style FLUX_CLI fill:#C1E7FF,stroke:#0077B6,color:#000
    style HELM_CLI fill:#C1E7FF,stroke:#0077B6,color:#000

    %% Source of Truth (Light Green/Aqua)
    style GIT fill:#D4EACD,stroke:#38761D,color:#000

    %% Production Homelab (Light Yellow/Gold)
    style K3S_CP fill:#FFF9C4,stroke:#FFC107,color:#000
    style K3S_WK fill:#FFF9C4,stroke:#FFC107,color:#000
    style FLUX_C fill:#FFF9C4,stroke:#FFC107,color:#000
    style APP fill:#FFF9C4,stroke:#FFC107,color:#000
```

* **Phase 1: Base OS Setup (Both Laptops)**
    * **Install Debian** (Minimal/Server version).
    * **Configure SSH** (Ensure server is running and accessible).
    * **Set Static IP** (Configure for stable networking).
    * **Disable Firewall** (Temporarily disable or adjust UFW for K3s traffic).

* **Phase 2: K3s Installation (Server & Agent)**
    * **Server (Laptop 1):**
        * Install **K3s Server** (Control Plane).
        * Retrieve the **Node Token** (from `/var/lib/rancher/k3s/server/node-token`).
    * **Agent (Laptop 2):**
        * Install **K3s Agent** using the token and the server's IP address.
    * **Verification (Dev Machine):**
        * Run `kubectl get nodes` to confirm both nodes are **Ready**.

* **Phase 3: GitOps Bootstrapping (From Dev Machine)**
    * **Install Flux CLI** on DevContainer.
    * **Bootstrap Flux** by running `flux bootstrap` and pointing it to Git repository.
    * **Verify Flux** with `kubectl get pods -n flux-system`.

* **Phase 4: Initial Deployment (Prometheus Stack)**
    * **Create Config Path** (e.g., `clusters/homelab/monitoring` in your Git repo).
    * **Define HelmRelease**
        * Create a YAML file defining the **Flux HelmRelease** custom resource.
        * Reference the `kube-prometheus-stack` **OCI chart** within the file.
    * **Commit and Push** the new YAML file to your remote Git repository.
    * **Verify Deployment** by watching Flux deploy the stack (e.g., `kubectl get pods -n monitoring`).
