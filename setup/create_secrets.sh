#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Restrict default permissions for any created files or processes
umask 077

# Get the directory of the script
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."

# Change to the project root directory
cd "$PROJECT_ROOT"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found. Please copy .env.sample to .env and fill in your secrets." >&2
    exit 1
fi

# Enforce strict file permissions on .env (owner read/write only: 0600)
CURRENT_PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%Lp" .env 2>/dev/null || true)
if [ -n "$CURRENT_PERMS" ] && [ "$CURRENT_PERMS" != "600" ] && [ "$CURRENT_PERMS" != "400" ]; then
    echo "Warning: .env permissions ($CURRENT_PERMS) are too permissive. Securing to 0600..." >&2
    chmod 600 .env
fi

# Load environment variables from .env file
set +u
source .env
set -u

# Validate required variables
REQUIRED_VARS=(SMTP_USER EMAIL_PASS SMTP_SERVER EMAIL_FROM EMAIL_TO)
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "Error: Required variable '$var' is not set or empty in .env." >&2
        exit 1
    fi
done

# Validate placeholder credentials
if [ "$EMAIL_PASS" = "your-email-password-or-app-key" ]; then
    echo "Error: EMAIL_PASS contains the default placeholder from .env.sample. Please update .env with actual credentials." >&2
    exit 1
fi

echo "Creating/updating secrets in Kubernetes..."

# Robusta Secret (Constructed values.yaml for Flux merging)
# This keeps the sensitive mailto URL out of the git repo.
# We must URL-encode the user and password as they might contain spaces or special characters like '@'.
# Credentials are passed via positional arguments (sys.argv[1]) to prevent shell interpolation and code injection.
ENCODED_USER=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$SMTP_USER")
ENCODED_PASS=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$EMAIL_PASS")
ROBUSTA_MAILTO="mailtos://$ENCODED_USER:$ENCODED_PASS@$SMTP_SERVER?from=$EMAIL_FROM&to=$EMAIL_TO"

# Pipe secret content via stdin to avoid exposing credentials in process listings (ps aux / /proc/<pid>/cmdline)
cat <<EOF | kubectl create secret generic robusta-secret-values \
  --namespace=monitoring \
  --from-file=values.yaml=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -
sinksConfig:
  - mail_sink:
      name: main_mail_sink
      mailto: "$ROBUSTA_MAILTO"
EOF

echo "Secret creation/update complete."
