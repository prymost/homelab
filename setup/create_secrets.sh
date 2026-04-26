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

# 2. Robusta Secret (Constructed values.yaml for Flux merging)
# This keeps the sensitive mailto URL out of the git repo.
# We must URL-encode the user and password as they might contain spaces or special characters like '@'.
ENCODED_USER=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$SMTP_USER'''))")
ENCODED_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$EMAIL_PASS'''))")
ROBUSTA_MAILTO="mailtos://$ENCODED_USER:$ENCODED_PASS@$SMTP_SERVER?from=$EMAIL_FROM&to=$EMAIL_TO"
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
