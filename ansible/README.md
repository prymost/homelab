# Homelab Automation with Ansible

This directory contains the Ansible playbooks and roles used to automate the configuration of all homelab machines.

## Architecture

The setup is divided into several modular roles:

- **`common`**: Applied to all machines. Handles SSH hardening, automated security updates, and basic utilities.
- **`k3s_prep`**: OS-level preparation for Kubernetes nodes. Handles kernel modules (`iptables`, `ipset`) and laptop-specific settings (preventing sleep on lid close).
- **`k3s`**: Bootstraps the K3s cluster.
  - Installs the Master node and retrieves the `node-token`.
  - Joins Agent nodes to the cluster using the token.
  - Automatically fetches and localises the `kubeconfig` to your DevContainer.
- **`kiosk`**: Dedicated configuration for the Debian + GNOME Kiosk PC. Handles auto-login, Firefox policies, and desktop environment tweaks.

## Getting Started

### 1. Prerequisites
Ansible is pre-installed in the project's DevContainer. Ensure your host's SSH keys are available to the container (the devcontainer is configured to bind-mount `~/.ssh`).

### 2. Inventory Setup
The inventory file contains private information (IP addresses, usernames) and is ignored by Git.
1. Copy the sample inventory:
   ```bash
   cp inventory/hosts.yml.sample inventory/hosts.yml
   ```
2. Edit `inventory/hosts.yml` with your specific machine details.

### 3. Running the Playbook
To apply the configuration to all machines:
```bash
ansible-playbook homelab.yml
```

### 4. Safety and Testing
Before applying changes to your live environment, use these flags to test safely:

- **Dry Run**: See what would change without actually making any modifications.
  ```bash
  ansible-playbook homelab.yml --check
  ```
- **Targeted Run**: Run the playbook only on specific machines (e.g., only the kiosk).
  ```bash
  ansible-playbook homelab.yml --limit kiosk
  ```
- **The "Safety Combo"**: Test changes on a specific machine before applying them everywhere.
  ```bash
  ansible-playbook homelab.yml --limit kiosk --check
  ```

## Security Best Practices
- **No Passwords**: This setup assumes SSH key-based authentication is already established on the target machines.
- **Private Data**: Never commit `inventory/hosts.yml` or any `vault.yml` files. These are protected by `.gitignore`.
