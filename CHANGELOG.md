I will record changes to this file just so i don't need to look at commit history every time

# Changelog
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
