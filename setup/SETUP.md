## 🛠️ Homelab Setup: Debian + K3s + Flux (To-Do List)

```mermaid
%% === Modern & Clean GitOps Flow (Revised) ===
graph LR
    %% Define styles, now with black text color for better visibility
    classDef dev fill:#e0f2fe,stroke:#3b82f6,stroke-width:2px,color:black;
    classDef git fill:#dcfce7,stroke:#22c55e,stroke-width:2px,color:black;
    classDef prod fill:#fefce8,stroke:#eab308,stroke-width:2px,color:black;
    classDef app fill:#fee2e2,stroke:#ef4444,stroke-width:2px,color:black;

    %% === Section 1: Development Environment ===
    subgraph Developer Environment
        subgraph DEV_CONTAINER [VS Code DevContainer]
            direction TB
            TOOLS("
                <div style='font-weight:bold; font-size:1.1em;'>CLI Tools</div>
                fa:fa-terminal Terminal<br/>
                fa:fa-cogs Flux CLI<br/>
                fa:fa-anchor Helm CLI
            ")
            K3D[fa:fa-cubes K3d Cluster]
        end
        TOOLS -- "1. Test & Validate" --> K3D
    end

    %% === Section 2: Source of Truth ===
    subgraph Source of Truth
        GIT[fa:fa-github GitHub Repo]
    end

    %% === Section 3: Production Environment ===
    subgraph Production Homelab
        subgraph K3s Cluster
            direction TB
            FLUX_C(fa:fa-sync Flux Controllers)
            %% Node text updated as requested
            K3S_CP["fa:fa-server Control Plane & Worker<br/>(Laptop 1)"]
            K3S_WK["fa:fa-server K3s Agent<br/>(Laptop 2)"]
            APP[fa:fa-chart-line Prometheus Stack]

            K3S_CP -- Manages --> K3S_WK
            FLUX_C -- "4. Applies Manifests" --> K3S_CP
            K3S_CP -- Deploys --> APP
        end
    end

    %% === Main Workflow Connections ===
    DEV_CONTAINER -- "2. Commit & Push YAML" --> GIT
    GIT -- "3. Pulls Changes" --> FLUX_C

    %% Apply defined styles to the nodes
    class DEV_CONTAINER,K3D,TOOLS dev;
    class GIT git;
    class K3S_CP,K3S_WK,FLUX_C prod;
    class APP app;
```

* **Phase 1: Base OS Setup (Both Laptops)** DONE
    * **Install Debian** (Minimal/Server version).
    * **Configure SSH** (Ensure server is running and accessible).
    * **Set Static IP** (Configure for stable networking).

* **Phase 2: K3s Installation (Server & Agent)** DONE
    * **Server (Laptop 1):**
        * Install **K3s Server** (Control Plane).
        * Retrieve the **Node Token** (from `/var/lib/rancher/k3s/server/node-token`).
    * **Agent (Laptop 2):**
        * Install **K3s Agent** using the token and the server's IP address.
    * **Verification (Dev Machine):**
        * Run `kubectl get nodes` to confirm both nodes are **Ready**.

* **Phase 3: GitOps Bootstrapping (From Dev Machine)** DONE
    * **Install Flux CLI** on DevContainer.
    * **Bootstrap Flux** by running `flux bootstrap` and pointing it to Git repository.
    * **Verify Flux** with `kubectl get pods -n flux-system`.

* **Phase 4: Initial Deployment (Prometheus Stack)** DONE
    * **Create Config Path** (e.g., `clusters/homelab/monitoring` in your Git repo).
    * **Define HelmRelease**
        * Create a YAML file defining the **Flux HelmRelease** custom resource.
        * Reference the `kube-prometheus-stack` **OCI chart** within the file.
    * **Commit and Push** the new YAML file to your remote Git repository.
    * **Verify Deployment** by watching Flux deploy the stack (e.g., `kubectl get pods -n monitoring`).
