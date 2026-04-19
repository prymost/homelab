A list of things i want to do in this project.
I do not want to be dependent on GitHub issues for tracking my tasks. At least not yet.
Once a TODO is complete, I will delete it from this list and record it in the [changelog](./CHANGELOG.md).

- Security improvements:
    - Enforce Pod Security Standards (e.g., 'baseline' or 'restricted').
    - Sign Git commits with GPG and configure FluxCD to verify them.
    - Harden the host OS (Ansible playbook?):
        - Disable unused services
        - Implement firewall rules
        - Regularly update and patch the OS
        - Something to check k8s versions regularly and update
        - Mitigate [[K3s exposes hostPort]]

- Things i want in my homelab:
    - Jellyfin? (Media server)
    - Homarr/Homepage? (Dashboard)
    - Caliber-web? (Ebook management)

- Followups
    - Fix Traefik dashboard in grafana. No data
    - Fix FluxCD dashboard in grafana. No data
    - Enhance network policies for monitoring stack

- Monitoring & Security Simplification:
    - Evaluate replacing Prometheus/Alertmanager with **VictoriaMetrics** or **Gatus** for lower resource usage.
    - Investigate **Botkube** for direct notifications (Discord/Telegram) on pod restarts, OOMKills, and errors.
    - Compare **Uptime Kuma** vs. **Gatus** for a lightweight "Status Page" and simple service health alerts.
    - Improve Trivy visibility: Evaluate **Trivy-UI** or Lens extensions to make the "1892 vulnerabilities" actionable.
    - Refine Trivy alerting: Only notify on *Critical* vulnerabilities in production namespaces to reduce noise.
