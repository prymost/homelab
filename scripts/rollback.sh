#!/usr/bin/env bash
# ==============================================================================
# Homelab Autonomous Rollback Script
# Automatically reverts the latest commit (or a specified commit), pushes the
# revert to GitHub, triggers FluxCD reconciliation, and runs verify-cluster.sh
# to ensure the cluster is restored to a 100% healthy state.
#
# Usage:
#   ./scripts/rollback.sh               # Reverts HEAD commit
#   ./scripts/rollback.sh <commit-sha>  # Reverts specific commit
# ==============================================================================

set -euo pipefail

# Colors
C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

TARGET_COMMIT="${1:-HEAD}"
COMMIT_TO_REVERT="$(git rev-parse "$TARGET_COMMIT")"
SHORT_SHA="${COMMIT_TO_REVERT:0:7}"
COMMIT_MSG="$(git log -1 --pretty=%B "$COMMIT_TO_REVERT" | head -n 1)"

echo -e "${C_CYAN}====================================================================${C_RESET}"
echo -e "${C_CYAN}  HOMELAB AUTONOMOUS ROLLBACK INITIATED${C_RESET}"
echo -e "${C_CYAN}  Target commit to revert: ${SHORT_SHA} (\"${COMMIT_MSG}\")${C_RESET}"
echo -e "${C_CYAN}====================================================================${C_RESET}"

# Step 1: Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo -e "${C_YELLOW}[WARN] Working directory has uncommitted changes. Stashing them...${C_RESET}"
  git stash push -m "rollback-stash-$(date +%s)"
fi

# Step 2: Git revert
echo -e "${C_BLUE}[INFO] Creating revert commit...${C_RESET}"
git revert "$COMMIT_TO_REVERT" --no-edit

REVERT_SHA="$(git rev-parse HEAD)"
REVERT_SHORT_SHA="${REVERT_SHA:0:7}"
echo -e "${C_GREEN}[PASS] Created revert commit ${REVERT_SHORT_SHA}${C_RESET}"

# Step 3: Push to GitHub
echo -e "${C_BLUE}[INFO] Pushing revert commit to origin main...${C_RESET}"
git push origin main
echo -e "${C_GREEN}[PASS] Pushed revert commit to origin main${C_RESET}"

# Step 4: Trigger FluxCD Sync & Wait for Cluster Recovery
echo -e "${C_BLUE}[INFO] Triggering FluxCD sync and waiting for cluster recovery...${C_RESET}"
"$REPO_DIR/scripts/verify-cluster.sh" --wait-sync --expect-commit "$REVERT_SHA"

echo ""
echo -e "${C_GREEN}>>> ROLLBACK COMPLETE: Cluster successfully restored to healthy state at ${REVERT_SHORT_SHA}! <<<${C_RESET}"
