#!/bin/bash

# This script automates the setup of a new Debian-based laptop for the homelab.

set -euo pipefail
IFS=$'\n\t'

# --- Configuration Variables ---
SSHD_CONFIG_PATH="/etc/ssh/sshd_config"
LOGIND_CONFIG_PATH="/etc/systemd/logind.conf"
INTERFACES_FILE_PATH="/etc/network/interfaces"

echo "Starting Debian bootstrap process..."
echo "This script will use sudo to run commands that require root privileges."

# --- SSH Configuration ---
echo "Configuring SSH..."
# Remove existing Port and PasswordAuthentication directives
sudo sed -i -e '/^#?Port/d' -e '/^#?PasswordAuthentication/d' "$SSHD_CONFIG_PATH"
# Add new directives
echo "Port 2221" | sudo tee -a "$SSHD_CONFIG_PATH" > /dev/null
echo "PasswordAuthentication no" | sudo tee -a "$SSHD_CONFIG_PATH" > /dev/null
sudo systemctl restart sshd
echo "SSH configured to use port 2221 and password authentication is disabled."

# --- Prevent Sleep on Lid Close ---
echo "Configuring system to not sleep when the lid is closed..."
# Remove existing HandleLidSwitch directive
sudo sed -i '/^#?HandleLidSwitch/d' "$LOGIND_CONFIG_PATH"
# Add new directive
echo "HandleLidSwitch=ignore" | sudo tee -a "$LOGIND_CONFIG_PATH" > /dev/null
sudo systemctl restart systemd-logind
echo "System will now ignore lid close events."

# --- Static IP Configuration ---
echo "Configuring static IP address..."
echo "This section is interactive. It will guide you to set a static IP."

# Backup existing interfaces file
if [ -f "$INTERFACES_FILE_PATH" ]; then
    sudo cp "$INTERFACES_FILE_PATH" "${INTERFACES_FILE_PATH}.bak"
    echo "Backed up $INTERFACES_FILE_PATH to ${INTERFACES_FILE_PATH}.bak"
fi

# Gather network information
echo "Available network interfaces:"
ip -o addr show | awk '{print $2}' | cut -d'@' -f1 | sort -u
read -p "Enter the name of the interface you want to configure (e.g., enp0s25): " interface_name

gateway=$(ip route | grep default | awk '{print $3}')
if [ -z "$gateway" ]; then
    read -p "Could not automatically determine gateway. Please enter gateway IP: " gateway
else
    echo "Detected gateway: $gateway"
fi

dns_servers=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')
if [ -z "$dns_servers" ];
then
    read -p "Could not automatically determine DNS servers. Please enter DNS server(s) separated by spaces: " dns_servers
else
    echo "Detected DNS servers: $dns_servers"
fi

read -p "Enter the static IP address you want to set (e.g., 192.168.1.50): " static_ip
read -p "Enter the netmask [255.255.255.0]: " netmask
netmask=${netmask:-255.255.255.0}

# Create temporary files to work with
original_interfaces=$(mktemp)
new_interfaces=$(mktemp)
auto_or_hotplug="auto" # Default

if [ -f "$INTERFACES_FILE_PATH" ]; then
    sudo cp "$INTERFACES_FILE_PATH" "$original_interfaces"
    # Check if the interface uses allow-hotplug
    if grep -q -E "^\s*allow-hotplug\s+$interface_name" "$original_interfaces"; then
        auto_or_hotplug="allow-hotplug"
    fi
else
    touch "$original_interfaces"
fi

echo "Commenting out previous configuration for $interface_name..."

found_interface=false
while IFS= read -r line || [[ -n "$line" ]]; do
  trimmed_line=$(echo "$line" | sed 's/^[ \t]*//')

  # Check for the end of an interface block before processing the line
  if [[ "$found_interface" == "true" ]] && ! [[ "$line" =~ ^[[:space:]] ]]; then
    found_interface=false
  fi

  # Comment out the auto/allow-hotplug line for the interface
  if [[ "$trimmed_line" =~ ^(auto|allow-hotplug)[[:space:]]+$interface_name ]]; then
    echo "#$line" >> "$new_interfaces"
  # Start of an interface block to comment out
  elif [[ "$trimmed_line" =~ ^iface[[:space:]]+$interface_name[[:space:]]+inet ]]; then
    found_interface=true
    echo "#$line" >> "$new_interfaces"
  # Any other line in the interface block
  elif [[ "$found_interface" == "true" ]]; then
    echo "#$line" >> "$new_interfaces"
  # Any other line not in the block
  else
    echo "$line" >> "$new_interfaces"
  fi
done < "$original_interfaces"

# Append new static configuration
echo "Appending new static configuration for $interface_name..."
{
    echo ""
    echo "# Static IP configuration for $interface_name added by bootstrap script"
    echo "$auto_or_hotplug $interface_name"
    echo "iface $interface_name inet static"
    echo "    address $static_ip"
    echo "    netmask $netmask"
    echo "    gateway $gateway"
    echo "    dns-nameservers $dns_servers"
} >> "$new_interfaces"

# Replace the original file with the modified one
sudo cp "$new_interfaces" "$INTERFACES_FILE_PATH"
rm "$original_interfaces" "$new_interfaces"

echo "$INTERFACES_FILE_PATH has been updated."
echo "********** IF YOU ARE USING WIFI, YOU NEED TO MANUALLY ADD WPA CONFIGURATION TO THE INTERFACES FILE **********"

# The 'networking' service might not be available on modern Debian systems
# using systemd-networkd or NetworkManager.
# We will try to restart it, but if it fails, it might not be an issue.
if systemctl list-units --type=service | grep -q 'networking.service'; then
    sudo systemctl restart networking
    echo "Networking service restarted."
else
    echo "The 'networking' service is not active. You might need to reboot or manually apply the changes (e.g., sudo ifdown $interface_name && sudo ifup $interface_name)."
fi

# --- Time Synchronization ---
echo "Verifying time synchronization..."
if ! timedatectl status | grep -q "System clock synchronized: yes"; then
    echo "System clock not synchronized. Enabling NTP..."
    sudo timedatectl set-ntp true
    echo "NTP enabled."
else
    echo "System clock is already synchronized."
fi

# --- Hardware Specifications ---
echo "--- Hardware Specifications ---"
echo "- CPU"
echo "  - $(grep "model name" /proc/cpuinfo | head -n 1 | sed 's/model name\s*:\s*//')"
echo "  - CPU cores: $(grep -c processor /proc/cpuinfo)"
echo "- RAM"
echo "  ` ` `"
free -h
echo "  ` ` `"
echo "- Storage"
echo "  ` ` `"
df -h /
lsblk -d -o NAME,ROTA
echo "  ` ` `"
echo "-----------------------------"

# --- Package Installation ---
echo "Installing required packages..."
sudo apt update && sudo apt upgrade -y -qq
sudo apt install -y kitty-terminfo curl iptables ipset nfs-common
sudo modprobe xt_set && sudo modprobe ip_set && sudo modprobe ip_set_hash_net
echo "Packages installed."


echo "Bootstrap process finished successfully."
echo "It is recommended to reboot the system to ensure all changes are applied."
