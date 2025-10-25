A list of things i want to do in this project.
I do not want to be dependent on GitHub issues for tracking my tasks. At least not yet.
Once a TODO is complete, I will delete it from this list and record it in the [changelog](./CHANGELOG.md).

- Compare outputs from Trivy, Kube-bench, Kubescape
- Security improvements:
    - Implement Network Policies to restrict pod-to-pod communication.
    - Enforce Pod Security Standards (e.g., 'baseline' or 'restricted').
    - Sign Git commits with GPG and configure FluxCD to verify them.
    - Harden the host OS (Ansible playbook?):
        - Disable unused services
        - Implement firewall rules
        - Regularly update and patch the OS
        - Something to check k8s versions regularly and update
        - Mitigate [[K3s exposes hostPort]]

- Things i want in my homelab:
    - Minecraft server
    - Family calendar + dashboard + todos (Nextcloud + Nextcloud calendar + Homarr, HomeAssistant dashboard, or similar)
    - Jellyfin? (Media server)
    - Homarr/Homepage? (Dashboard)
    - Caliber-web? (Ebook management)

- Data persistence strategy
    - Long term: NAS (Synology)
    - Short term: Bind mounts to host machine
