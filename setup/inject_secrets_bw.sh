#!/bin/bash
set -euo pipefail
# Disable tracing to prevent accidental credential leakage in shell debug logs
set +x 2>/dev/null || true
IFS=$'\n\t'

# Restrict default permissions for any created sub-processes or files
umask 077

# Ensure any in-memory Bitwarden session key and payloads are wiped upon exit or interruption
cleanup() {
    unset BW_SESSION ITEM_JSON ROBUSTA_VALUES
}
trap cleanup EXIT INT TERM

# Resolve project root directory
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."
cd "$PROJECT_ROOT"

# Check required tooling
for cmd in bw kubectl python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' is not installed or not in PATH." >&2
        exit 1
    fi
done

# Check Bitwarden login status
BW_STATUS=$(bw status 2>/dev/null | python3 -c 'import sys, json; print(json.load(sys.stdin).get("status", "unknown"))' 2>/dev/null || echo "unknown")

if [ "$BW_STATUS" = "unauthenticated" ]; then
    echo "Bitwarden CLI is not authenticated. Please log in:" >&2
    bw login
fi

# Check vault lock status and unlock interactively if needed
# BW_SESSION is kept strictly local to this shell (never globally exported)
BW_SESSION="${BW_SESSION:-}"
if ! bw unlock --check >/dev/null 2>&1; then
    echo "Bitwarden vault is locked. Please enter your master password to unlock:" >&2
    BW_SESSION=$(bw unlock --raw)
fi

# Security & Anti-Reconnaissance:
# Avoid committing internal vault item titles or personal hierarchies to public git.
# Operators can supply BW_ITEM_NAME via environment or enter it interactively.
ITEM_NAME="${BW_ITEM_NAME:-}"
if [ -z "$ITEM_NAME" ]; then
    read -r -p "Enter Bitwarden Secret Note name for homelab secrets: " ITEM_NAME
    if [ -z "$ITEM_NAME" ]; then
        echo "Error: Bitwarden item name cannot be empty." >&2
        exit 1
    fi
fi

echo "Fetching secrets from Bitwarden..." >&2

# Atomic single-item JSON retrieval directly into memory.
# BW_SESSION is scoped strictly to the bw subprocess call.
ITEM_JSON=$(BW_SESSION="$BW_SESSION" bw get item "$ITEM_NAME")

# Immediately scrub session key from memory; downstream processes do not need vault access
unset BW_SESSION

echo "Validating secret fields and preparing Kubernetes manifests in-memory..." >&2

# Validate and construct Robusta values.yaml in-memory without disk write or command-line exposure
ROBUSTA_VALUES=$(printf '%s' "$ITEM_JSON" | python3 -c '
import json
import sys
import urllib.parse

try:
    data = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write(f"Error parsing Bitwarden item JSON: {e}\n")
    sys.exit(1)

fields = {f.get("name"): f.get("value") for f in data.get("fields", []) if f.get("name")}

required = ["SMTP_USER", "EMAIL_PASS", "SMTP_SERVER", "EMAIL_FROM", "EMAIL_TO"]
missing = [k for k in required if not fields.get(k)]
if missing:
    missing_str = ", ".join(missing)
    sys.stderr.write(f"Error: Missing or empty required secret field(s) in Bitwarden item: {missing_str}\n")
    sys.exit(1)

if fields["EMAIL_PASS"] == "your-email-password-or-app-key":
    sys.stderr.write("Error: EMAIL_PASS contains placeholder text. Please update your Bitwarden vault with actual credentials.\n")
    sys.exit(1)

# Strict URL encoding with safe="" ensures special characters (e.g. slashes or @ in passwords) do not break URL authority parsing
encoded_user = urllib.parse.quote(fields["SMTP_USER"], safe="")
encoded_pass = urllib.parse.quote(fields["EMAIL_PASS"], safe="")
smtp_server = fields["SMTP_SERVER"]
email_from = fields["EMAIL_FROM"]
email_to = fields["EMAIL_TO"]

mailto = f"mailtos://{encoded_user}:{encoded_pass}@{smtp_server}?from={email_from}&to={email_to}"

# Use json.dumps to format the string scalar, guaranteeing safe YAML escaping against newline/delimiter injection
escaped_mailto = json.dumps(mailto)

values_yaml = f"""sinksConfig:
  - mail_sink:
      name: main_mail_sink
      mailto: {escaped_mailto}
"""
sys.stdout.write(values_yaml)
')

# Scrub raw JSON payload from memory
unset ITEM_JSON

if [ -z "$ROBUSTA_VALUES" ]; then
    echo "Error: Generated Robusta secret payload is empty. Aborting without modifying Kubernetes." >&2
    exit 1
fi

echo "Applying secret 'robusta-secret-values' to namespace 'monitoring' via stdin..." >&2

printf '%s' "$ROBUSTA_VALUES" | kubectl create secret generic robusta-secret-values \
  --namespace=monitoring \
  --from-file=values.yaml=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -

# Explicitly clear remaining secret payload from memory
cleanup

echo "Secret injection completed successfully."
