#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Get the directory of the script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."

# Change to the project root directory
cd "$PROJECT_ROOT"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please copy .env.sample to .env and fill in your secrets."
    exit 1
fi

# Load environment variables from .env file
source .env

echo "Creating/updating secrets in Kubernetes..."

# Create the secret using kubectl apply (idempotent)
# This command creates the secret manifest and pipes it to `kubectl apply`.
# `apply` will create the secret if it doesn't exist, or update it if it does.
kubectl create secret generic alertmanager-email-creds \
  --from-literal=email_from="$EMAIL_FROM" \
  --from-literal=email_pass="$EMAIL_PASS" \
  --from-literal=email_to="$EMAIL_TO" \
  --namespace=monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret creation/update complete."
