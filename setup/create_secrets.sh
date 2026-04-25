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

# 1. Alertmanager Secret (Traditional key-value pairs)
kubectl create secret generic alertmanager-email-creds \
  --from-literal=email_from="$EMAIL_FROM" \
  --from-literal=email_pass="$EMAIL_PASS" \
  --from-literal=email_to="$EMAIL_TO" \
  --namespace=monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Robusta Secret (Constructed values.yaml for Flux merging)
# This keeps the sensitive mailto URL out of the git repo.
ROBUSTA_MAILTO="mailtos://$SMTP_USER:$EMAIL_PASS@$SMTP_SERVER?from=$EMAIL_FROM&to=$EMAIL_TO"
ROBUSTA_YAML=$(cat <<EOF
sinksConfig:
  - mail_sink:
      name: main_mail_sink
      mailto: "$ROBUSTA_MAILTO"
EOF
)

kubectl create secret generic robusta-secret-values \
  --from-literal=values.yaml="$ROBUSTA_YAML" \
  --namespace=monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret creation/update complete."
