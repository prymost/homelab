I will record changes to this file just so i don't need to look at commit history every time

# Changelog
2026-10-25:
- Re-architected homelab secret management to use Bitwarden CLI (`bw`):
  - Created `setup/inject_secrets_bw.sh`: securely unlocks Bitwarden on-demand, retrieves credentials in-memory via a single atomic call, and pipes Kubernetes Secret manifests via stdin (`kubectl apply -f -`) with zero disk writes, zero `ps aux` command-line exposure, and automatic session/payload memory scrubbing.
  - Implemented anti-reconnaissance protections: eliminated hardcoded vault item titles in public git files in favor of dynamic environment variable / interactive prompting.
- Added Hermes Agent secret injection support to `setup/inject_secrets_bw.sh` and `setup/render_secrets.py`.
- Implemented Storage, RBAC, and Network Isolation for Hermes Agent (`sandbox/hermes-agent/`).
- Deployed Hermes Agent base GitOps workload (`sandbox/hermes-agent/` and `clusters/homelab/hermes-agent/`):
  - Created hardened base `Deployment` with non-root UID 10000, `readOnlyRootFilesystem: true`, capabilities dropped to `ALL`, `RuntimeDefault` seccomp, explicit CPU/memory limits, and pinned semantic digest `nousresearch/hermes-agent:stable@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d`.
  - Added permissions initContainer (`alpine:3.21.3`) ensuring non-root NFS mount ownership (`10000:10000`, `0770`) without relying on NAS defaults.
  - Configured ConfigMap with `database.journal_mode: delete` for safe SQLite concurrency over NFS, custom OpenAI backend routing to OpenCode Go API (`https://opencode.ai/zen/go/v1`), and sandboxed toolsets (`platform_toolsets.telegram: [web, file, skills, todo]`).
  - Implemented least-privilege secret mapping (`valueFrom.secretKeyRef`) from `hermes-agent-secrets`.
  - Integrated Hermes Agent overlay into root GitOps catalog (`clusters/homelab/kustomization.yaml`).
- Hardened `monitoring` NetworkPolicies.

2026-10-22:
- Hardened Traefik Ingress for Home Assistant:
  - Created Traefik `Middleware` (`home-assistant-headers`) injecting defense-in-depth security headers: `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection: 1; mode=block`, `Referrer-Policy: strict-origin-when-cross-origin`, and `X-Robots-Tag: noindex, nofollow, nosnippet`.
  - Attached middleware to `home-assistant-ingress` while preserving internal `.lan` HTTP access without forced HTTPS redirects, preventing Kiosk dashboard disruption and browser untrusted certificate blocks.
- Hardened Ansible automation playbooks:
  - Added SSH configuration syntax validation (`validate: '/usr/sbin/sshd -t -f %s'`) and explicit `PermitRootLogin prohibit-password` in common role.
  - Pinned K3s installation version (`INSTALL_K3S_VERSION: "v1.33.5+k3s1"`) in inventory `group_vars/all.yml` and role defaults to prevent unexpected upstream drift and supply-chain tampering.
  - Removed persistent fact caching (`cacheable: yes`) for cluster node tokens in K3s master role to prevent plaintext storage on disk.
  - Dynamically resolved control machine user home directory (`lookup('env', 'HOME')`) for localized kubeconfig storage and ensured secure permissions (`0700` directory, `0600` file).

2026-10-21:
- Hardened secret creation workflow (`setup/create_secrets.sh`): piped secrets via stdin (`--from-file=values.yaml=/dev/stdin`) to eliminate `ps aux` command-line credential exposure, used positional arguments into Python to prevent shell injection, added strict `.env` file permission enforcement (`chmod 600`), and added validation for required variables and sample placeholders.
- Fixed Home Assistant deployment strategy to `Recreate` to prevent `RollingUpdate` dual-instance lock contention on `/config/.ha_run.lock` during upgrades.
- Hardened cluster verification suite (`scripts/verify-cluster.sh`) to detect deployment replica anomalies and enforce strict timeout checking on rollout completions.

2026-10-20:
- Built autonomous cluster verification suite (`scripts/verify-cluster.sh`) with 21 live health checks and `--wait-sync` FluxCD reconciliation polling.
- Built autonomous rollback script (`scripts/rollback.sh`) to automatically revert breaking commits and restore green cluster state.
- Enforced least-privilege network policies (`default-deny`, DNS, K8s API, and storage/external egress) for `nfs-provisioner` and `monitoring` namespaces.
- Pruned Kubernetes API egress (`10.43.0.1:443`) from `home-assistant` and `minecraft` workloads.
- Expanded `home-assistant` ingress NetworkPolicy to explicitly allow multi-node routing via `homelab2`.

2026-05-22:
- Migrated devcontainer configuration from legacy Gemini CLI to Antigravity CLI.
- Replaced GEMINI.md with ANTIGRAVITY.md.

2026-04-28:
- Improved kiosk resiliency by adding an auto-restart loop and an idle-reset monitor.
- Updated Ansible kiosk role to deploy launcher and monitor scripts to ~/.local/bin.
- Configured GNOME autostart entries for persistent dashboard availability.
2026-04-27:
- Fixed Trivy server NetworkPolicy to use correct 'app: trivy' labels
- Increased Trivy server and scan job memory limits to 4Gi to support large images (Home Assistant)
2026-04-26:
- Added Ansible playbook to manage homalab nodes and the kiosk.
2026-04-24:
- Replaced Prometheus/Alertmanager/Grafana monitoring stack with lightweight Robusta for reduced resource usage and high-signal alerting
2026-04-19:
- Update Home Assistant dashboard with VPN toggles
2026-04-18:
- Changing Trivy to cliet-server mode
2026-04-13:
- Fixed Trivy Operator egress NetworkPolicies to allow specific access to the Kubernetes API server
- Fixed Home Assistant and Minecraft NetworkPolicies to allow API server access and corrected broad CIDR exceptions
- Added resource limits and enabled NetworkPolicy for kube-state-metrics to improve stability and connectivity
- Updated devcontainer to make it simpler and include gemini cli so it can access both k8s clusters
- Removing Mealie
2025-12-14:
- Home Assistant is running with family dashboard
2025-11-08:
- Added fully working Minecraft server via Helm chart
- Added network policies to allow ingress traffic from Traefik to Minecraft server restricting everything else
2025-11-02:
- Fixed Trivy Operator network policies. No failed scans anymore
2025-11-01:
- Removed manual network policies for the monitoring stack since could not figure out why default dashboards and default data source were not showing up
- Added very loose network policies via Helm chart values. Would have to revisit later to tighten them up
2025-10-30:
- Added network policies for Trivy Operator
2025-10-27:
- Attempting to add network policies to Mealie. Can't test those in a devcontainer as networking is different there
2025-10-24:
- Configured Alertmanager to send alerts via email
- Added alerting rules in the monitoring stack
2025-10-14:
- Refactored yaml files in the clusters/homelab directory to use values files from the sandbox directory for consistency
- Added some dashboards to the monitoring stack for Traefik and FluxCD
- Added Github Actions workflow to run trivy scans on PRs
2025-10-13:
- Added Trivy Operator for in-cluster security scans
2025-10-12:
- Added pvc to more resources in the monitoring stack to ensure data persistence
- Added ingress for the Alertmanager UI
- Also added more limits and requests to the monitoring stack resources
2025-10-10:
- Split Mealie manifests into separate files for better organization
- Add ingress for Mealie
2025-10-09:
- Added monitoring stack (Prometheus + Grafana + Alertmanager) to the cluster
2025-10-08:
- Updated setup/SETUP.md as i'm done installing k3s
2025-10-07:
- Added setup/debian_bootstrap.sh script for initial Debian setup
2025-10-04:
- Added helm to the devcontainer. Confirmed by installing monitoring stack with helm
- Added setup/SETUP.md with the setup plan and a diagram in mermaid syntax
2025-10-02:
- Made devcontainers work with k3s for easier local development
- Updated README.md with devcontainer instructions
2025-09-29:
- Moved out of the sandbox repo and validated the devcontainer setup
2025-09-28:
- Added devcontainer files
2025-09-27:
- Initial commit
