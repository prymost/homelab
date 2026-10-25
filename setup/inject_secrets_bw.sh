#!/bin/bash
set -euo pipefail
# Disable tracing to prevent accidental credential leakage in shell debug logs
set +x 2>/dev/null || true
IFS=$'\n\t'

# Restrict default permissions for any created sub-processes or files
umask 077

# Ensure any in-memory Bitwarden session key and payloads are wiped upon exit or interruption
cleanup() {
    unset BW_SESSION ITEM_JSON MANIFESTS
}
trap cleanup EXIT HUP INT TERM

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
if ! BW_SESSION="$BW_SESSION" bw unlock --check >/dev/null 2>&1; then
    echo "Bitwarden vault is locked. Please enter your master password to unlock:" >&2
    BW_SESSION=$(bw unlock --raw)
fi

# Operators can supply BW_ITEM_NAME via environment or enter it interactively
ITEM_NAME="${BW_ITEM_NAME:-}"
if [ -z "$ITEM_NAME" ]; then
    read -r -p "Enter Bitwarden Secret Note name for homelab secrets: " ITEM_NAME
    if [ -z "$ITEM_NAME" ]; then
        echo "Error: Bitwarden item name cannot be empty." >&2
        exit 1
    fi
fi

echo "Syncing latest vault data from Bitwarden..." >&2
BW_SESSION="$BW_SESSION" bw sync >/dev/null

echo "Fetching secrets from Bitwarden..." >&2

# Atomic single-item JSON retrieval directly into memory.
ITEM_JSON=$(BW_SESSION="$BW_SESSION" bw get item "$ITEM_NAME")

# Immediately scrub session key from memory
unset BW_SESSION

echo "Rendering Kubernetes secrets in-memory..." >&2

MANIFESTS=$(printf '%s' "$ITEM_JSON" | python3 "$SCRIPT_DIR/render_secrets.py")
unset ITEM_JSON

if [ -z "$MANIFESTS" ]; then
    echo "No matching secrets found to apply." >&2
    cleanup
    exit 0
fi

echo "Applying Kubernetes secrets via stdin..." >&2
printf '%s' "$MANIFESTS" | kubectl apply -f -
unset MANIFESTS

# Explicitly clear remaining secret payload from memory
cleanup

echo "Secret injection completed successfully."
