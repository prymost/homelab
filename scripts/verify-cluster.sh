#!/usr/bin/env bash
# ==============================================================================
# Homelab Autonomous Verification Script
# Verifies GitOps (FluxCD), Home Assistant, Minecraft, NFS Storage, Robusta,
# and overall cluster workload health.
#
# NOTE: This script is fully generic and public-safe. Zero hardcoded IP addresses,
# personal names, credentials, or internal domain names are stored in this script.
# All endpoints and cluster topology are dynamically discovered at runtime via
# standard Kubernetes API queries (with optional environment variable overrides).
#
# Usage:
#   ./scripts/verify-cluster.sh                 # Run standard test suite
#   ./scripts/verify-cluster.sh --wait-sync      # Trigger Flux reconcile & wait for HEAD
#   ./scripts/verify-cluster.sh --expect-commit <SHA> # Verify specific commit was reconciled
#   ./scripts/verify-cluster.sh --quick         # Fast check (skip deep log inspections)
# ==============================================================================

set -uo pipefail

# Colors
C_RESET="\033[0m"
C_RED="\033[1;31m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"

# Config & Discovery Defaults (Can be overridden by environment variables)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAIT_SYNC=false
TIMEOUT_SECONDS=180
EXPECT_COMMIT=""
QUICK_MODE=false

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait-sync)
      WAIT_SYNC=true
      shift
      ;;
    --expect-commit)
      EXPECT_COMMIT="$2"
      shift 2
      ;;
    --quick)
      QUICK_MODE=true
      shift
      ;;
    --timeout)
      TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--wait-sync] [--expect-commit <SHA>] [--quick] [--timeout <secs>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

log_info() {
  echo -e "${C_BLUE}[INFO]${C_RESET} $1"
}

log_pass() {
  echo -e "${C_GREEN}[PASS]${C_RESET} $1"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_fail() {
  echo -e "${C_RED}[FAIL]${C_RESET} $1"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_warn() {
  echo -e "${C_YELLOW}[WARN]${C_RESET} $1"
}

log_header() {
  echo ""
  echo -e "${C_CYAN}====================================================================${C_RESET}"
  echo -e "${C_CYAN} $1${C_RESET}"
  echo -e "${C_CYAN}====================================================================${C_RESET}"
}

# ------------------------------------------------------------------------------
# Dynamic Endpoint Discovery (Zero Hardcoded IPs or Private Domains)
# ------------------------------------------------------------------------------
discover_endpoints() {
  # Discover Node Names and Internal IPs dynamically
  # Format: array of "node_name:ip"
  mapfile -t DISCOVERED_NODES < <(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}:{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' 2>/dev/null | grep -v '^:' | grep -v '^$')

  # Discover NFS Server IP dynamically from existing PersistentVolumes
  DISCOVERED_NFS_SERVER="${HOMELAB_NFS_SERVER:-$(kubectl get pv -o jsonpath='{.items[*].spec.nfs.server}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -n 1 || echo "")}"

  # Discover Home Assistant Ingress Host dynamically from Ingress spec
  DISCOVERED_HA_HOST="${HOMELAB_HA_HOST:-$(kubectl get ingress -n home-assistant -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || echo "")}"
}

# ------------------------------------------------------------------------------
# Optional: Trigger FluxCD Sync and Wait
# ------------------------------------------------------------------------------
wait_for_flux_sync() {
  local target_sha="${EXPECT_COMMIT}"
  if [[ -z "$target_sha" ]]; then
    target_sha="$(git -C "$REPO_DIR" rev-parse HEAD)"
  fi
  local short_sha="${target_sha:0:7}"

  log_info "Triggering Flux reconciliation for commit ${short_sha}..."
  local now
  now="$(date +%s)"
  kubectl annotate --overwrite gitrepository -n flux-system flux-system "reconcile.fluxcd.io/requestedAt=${now}" >/dev/null 2>&1 || true
  kubectl annotate --overwrite kustomization -n flux-system flux-system "reconcile.fluxcd.io/requestedAt=${now}" >/dev/null 2>&1 || true

  log_info "Waiting for FluxCD to apply revision containing ${short_sha} (timeout ${TIMEOUT_SECONDS}s)..."
  local start_time
  start_time="$(date +%s)"

  while true; do
    local current_time
    current_time="$(date +%s)"
    local elapsed=$((current_time - start_time))

    if [[ $elapsed -gt $TIMEOUT_SECONDS ]]; then
      log_fail "FluxCD reconciliation timed out after ${TIMEOUT_SECONDS}s waiting for commit ${short_sha}!"
      return 1
    fi

    local kustomize_ready kustomize_rev
    kustomize_ready="$(kubectl get kustomization -n flux-system flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")"
    kustomize_rev="$(kubectl get kustomization -n flux-system flux-system -o jsonpath='{.status.lastAppliedRevision}' 2>/dev/null || echo "")"

    if [[ "$kustomize_ready" == "True" && "$kustomize_rev" == *"$target_sha"* ]]; then
      log_pass "FluxCD successfully reconciled commit ${short_sha} (${kustomize_rev})"
      sleep 5
      break
    fi

    sleep 3
  done
}

# ------------------------------------------------------------------------------
# Test 1: Node Status
# ------------------------------------------------------------------------------
check_nodes() {
  log_header "1. Cluster Nodes & Host Health"
  local not_ready
  not_ready="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1, $2}')"
  if [[ -z "$not_ready" ]]; then
    local node_list
    node_list="$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1 "(" $2 ")"}' | tr '\n' ' ')"
    log_pass "All Kubernetes nodes are Ready: ${node_list}"
  else
    log_fail "Nodes not Ready: ${not_ready}"
  fi
}

# ------------------------------------------------------------------------------
# Test 2: Core Infrastructure (CoreDNS, Traefik)
# ------------------------------------------------------------------------------
check_core_infrastructure() {
  log_header "2. Core Infrastructure (CoreDNS & Traefik Ingress)"

  local coredns_ready
  coredns_ready="$(kubectl get deployment -n kube-system coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  if [[ "$coredns_ready" -ge 1 ]]; then
    log_pass "CoreDNS is healthy (${coredns_ready} ready replica)"
  else
    log_fail "CoreDNS is not ready (ready replicas: ${coredns_ready})"
  fi

  local traefik_ready
  traefik_ready="$(kubectl get deployment -n kube-system traefik -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  if [[ "$traefik_ready" -ge 1 ]]; then
    log_pass "Traefik Ingress Controller is healthy (${traefik_ready} ready replica)"
  else
    log_fail "Traefik Ingress Controller is not ready (ready replicas: ${traefik_ready})"
  fi
}

# ------------------------------------------------------------------------------
# Test 3: FluxCD & HelmReleases Status
# ------------------------------------------------------------------------------
check_gitops_flux() {
  log_header "3. GitOps & FluxCD State"

  # GitRepository
  local gitrepo_ready gitrepo_rev
  gitrepo_ready="$(kubectl get gitrepository -n flux-system flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")"
  gitrepo_rev="$(kubectl get gitrepository -n flux-system flux-system -o jsonpath='{.status.artifact.revision}' 2>/dev/null || echo "unknown")"
  if [[ "$gitrepo_ready" == "True" ]]; then
    log_pass "Flux GitRepository 'flux-system' is Ready (${gitrepo_rev})"
  else
    log_fail "Flux GitRepository 'flux-system' is NOT Ready!"
  fi

  # Kustomization
  local kustomize_ready kustomize_reason
  kustomize_ready="$(kubectl get kustomization -n flux-system flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")"
  kustomize_reason="$(kubectl get kustomization -n flux-system flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "unknown")"
  if [[ "$kustomize_ready" == "True" && "$kustomize_reason" == "ReconciliationSucceeded" ]]; then
    log_pass "Flux Kustomization 'flux-system' is Ready (${kustomize_reason})"
  else
    local kustomize_msg
    kustomize_msg="$(kubectl get kustomization -n flux-system flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "")"
    log_fail "Flux Kustomization 'flux-system' NOT Ready! Reason: ${kustomize_reason}, Msg: ${kustomize_msg}"
  fi

  # HelmReleases check
  python3 -c '
import subprocess, sys, json
res = subprocess.run(["kubectl", "get", "helmreleases", "-A", "-o", "json"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
if res.returncode != 0:
    print("Failed to query HelmReleases", file=sys.stderr)
    sys.exit(1)
data = json.loads(res.stdout)
failed = []
passed = []
for hr in data.get("items", []):
    ns = hr["metadata"]["namespace"]
    name = hr["metadata"]["name"]
    conditions = {c["type"]: c for c in hr.get("status", {}).get("conditions", [])}
    ready_c = conditions.get("Ready", {})
    reason = ready_c.get("reason", "Unknown")
    if ready_c.get("status") == "True":
        passed.append(f"{ns}/{name}")
    else:
        failed.append(f"{ns}/{name} ({reason})")

if failed:
    print("Failed HelmReleases: " + ", ".join(failed), file=sys.stderr)
    sys.exit(1)
else:
    print(f"All {len(passed)} HelmReleases are Ready: " + ", ".join(passed))
    sys.exit(0)
'
  if [[ $? -eq 0 ]]; then
    log_pass "All HelmReleases in cluster are in Ready condition"
  else
    log_fail "One or more HelmReleases are failing!"
  fi
}

# ------------------------------------------------------------------------------
# Test 4: Home Assistant Workload & Ingress Probe
# ------------------------------------------------------------------------------
check_home_assistant() {
  log_header "4. Home Assistant Application & Ingress"

  local ha_ready
  ha_ready="$(kubectl get deployment -n home-assistant home-assistant -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  if [[ "$ha_ready" -ge 1 ]]; then
    log_pass "Home Assistant pod is 1/1 Running and Ready"
  else
    log_fail "Home Assistant pod is NOT ready (readyReplicas: ${ha_ready})"
  fi

  local ha_pvc
  ha_pvc="$(kubectl get pvc -n home-assistant ha-config -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")"
  if [[ "$ha_pvc" == "Bound" ]]; then
    log_pass "Home Assistant PVC 'ha-config' is Bound"
  else
    log_fail "Home Assistant PVC 'ha-config' status is: ${ha_pvc}"
  fi

  if [[ ${#DISCOVERED_NODES[@]} -eq 0 || -z "$DISCOVERED_HA_HOST" ]]; then
    log_warn "Skipping Home Assistant HTTP ingress probe (no nodes or ingress host discovered)"
    return
  fi

  for node_entry in "${DISCOVERED_NODES[@]}"; do
    local node_name="${node_entry%%:*}"
    local node_ip="${node_entry##*:}"
    if [[ -z "$node_ip" ]]; then continue; fi

    python3 -c '
import urllib.request, sys
ip, host = sys.argv[1], sys.argv[2]
req = urllib.request.Request(f"http://{ip}/", headers={"Host": host, "User-Agent": "HomelabVerification/1.0"})
try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        if resp.status == 200:
            sys.exit(0)
        sys.exit(1)
except Exception:
    sys.exit(1)
' "$node_ip" "$DISCOVERED_HA_HOST"
    if [[ $? -eq 0 ]]; then
      log_pass "Home Assistant HTTP 200 OK via node \"${node_name}\""
    else
      log_fail "Home Assistant HTTP probe failed via node \"${node_name}\""
    fi
  done
}

# ------------------------------------------------------------------------------
# Test 5: Minecraft Workload & Connectivity Probe
# ------------------------------------------------------------------------------
check_minecraft() {
  log_header "5. Minecraft Game Server & TCP Port 25565"

  local mc_ready
  mc_ready="$(kubectl get deployment -n minecraft minecraft -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  if [[ "$mc_ready" -ge 1 ]]; then
    log_pass "Minecraft server pod is 1/1 Running and Ready"
  else
    log_fail "Minecraft server pod is NOT ready (readyReplicas: ${mc_ready})"
  fi

  local mc_pvc
  mc_pvc="$(kubectl get pvc -n minecraft minecraft-datadir -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")"
  if [[ "$mc_pvc" == "Bound" ]]; then
    log_pass "Minecraft PVC 'minecraft-datadir' is Bound"
  else
    log_fail "Minecraft PVC 'minecraft-datadir' status is: ${mc_pvc}"
  fi

  if [[ ${#DISCOVERED_NODES[@]} -eq 0 ]]; then
    log_warn "Skipping Minecraft TCP probe (no nodes discovered)"
    return
  fi

  for node_entry in "${DISCOVERED_NODES[@]}"; do
    local node_name="${node_entry%%:*}"
    local node_ip="${node_entry##*:}"
    if [[ -z "$node_ip" ]]; then continue; fi

    python3 -c '
import socket, sys
ip, port = sys.argv[1], int(sys.argv[2])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(4)
try:
    s.connect((ip, port))
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
' "$node_ip" 25565
    if [[ $? -eq 0 ]]; then
      log_pass "Minecraft TCP connection established to node \"${node_name}\":25565"
    else
      log_fail "Minecraft TCP probe failed to node \"${node_name}\":25565"
    fi
  done
}

# ------------------------------------------------------------------------------
# Test 6: NFS Provisioner & Storage Health
# ------------------------------------------------------------------------------
check_storage_nfs() {
  log_header "6. NFS Provisioner & Persistent Storage"

  local nfs_ready
  nfs_ready="$(kubectl get deployment -n nfs-provisioner nfs-subdir-external-provisioner -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  if [[ "$nfs_ready" -ge 1 ]]; then
    log_pass "NFS subdir provisioner pod is 1/1 Running"
  else
    log_fail "NFS subdir provisioner pod is NOT ready (readyReplicas: ${nfs_ready})"
  fi

  if [[ -n "$DISCOVERED_NFS_SERVER" ]]; then
    python3 -c '
import socket, sys
ip, port = sys.argv[1], int(sys.argv[2])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(3)
try:
    s.connect((ip, port))
    s.close()
    sys.exit(0)
except Exception:
    sys.exit(1)
' "$DISCOVERED_NFS_SERVER" 2049
    if [[ $? -eq 0 ]]; then
      log_pass "NAS NFS storage service reachable on port 2049"
    else
      log_fail "NAS NFS storage service UNREACHABLE on port 2049"
    fi
  else
    log_warn "No NFS server discovered from PVs; skipping port 2049 probe"
  fi

  # Check all existing PVCs
  local unbound_count
  unbound_count="$(kubectl get pvc -A --no-headers 2>/dev/null | awk '$3 != "Bound" {print $1 "/" $2}' | wc -l)"
  if [[ "$unbound_count" -eq 0 ]]; then
    local total_pvcs
    total_pvcs="$(kubectl get pvc -A --no-headers 2>/dev/null | wc -l)"
    log_pass "All ${total_pvcs} PVCs cluster-wide are Bound"
  else
    log_fail "Found ${unbound_count} PVC(s) not in Bound state!"
  fi
}

# ------------------------------------------------------------------------------
# Test 7: Robusta Monitoring Stack
# ------------------------------------------------------------------------------
check_monitoring_robusta() {
  log_header "7. Monitoring & Robusta Event Pipeline"

  local runner_ready forwarder_ready
  runner_ready="$(kubectl get deployment -n monitoring robusta-runner -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"
  forwarder_ready="$(kubectl get deployment -n monitoring robusta-forwarder -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")"

  if [[ "$runner_ready" -ge 1 && "$forwarder_ready" -ge 1 ]]; then
    log_pass "Robusta runner and forwarder pods are Running (1/1 each)"
  else
    log_fail "Robusta pods not ready! Runner: ${runner_ready}, Forwarder: ${forwarder_ready}"
  fi

  if [[ "$QUICK_MODE" == false ]]; then
    local recent_fwd_logs
    recent_fwd_logs="$(kubectl logs -n monitoring deployment/robusta-forwarder --tail=30 2>/dev/null || echo "")"
    if echo "$recent_fwd_logs" | grep -q "Message successfully sent to http://robusta-runner:80"; then
      log_pass "Robusta forwarder is actively delivering events to robusta-runner:80"
    else
      log_warn "No recent forwarder delivery log entries found in last 30 lines (cluster might be idle)"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Test 8: Cluster-Wide Pod Health Scan
# ------------------------------------------------------------------------------
check_pod_anomalies() {
  log_header "8. Cluster-Wide Pod Health & Anomaly Scan"

  local unhealthy_pods
  unhealthy_pods="$(python3 -c '
import subprocess, sys, json
res = subprocess.run(["kubectl", "get", "pods", "-A", "-o", "json"], stdout=subprocess.PIPE, text=True)
data = json.loads(res.stdout)
unhealthy = []
for item in data.get("items", []):
    ns = item["metadata"]["namespace"]
    name = item["metadata"]["name"]
    phase = item["status"].get("phase", "Unknown")
    
    if phase == "Succeeded":
        continue
    if phase in ["Failed", "Unknown"]:
        unhealthy.append(f"{ns}/{name}: phase={phase}")
        continue
        
    for cs in item.get("status", {}).get("containerStatuses", []):
        cname = cs.get("name", "")
        state = cs.get("state", {})
        if "waiting" in state:
            reason = state["waiting"].get("reason", "Waiting")
            unhealthy.append(f"{ns}/{name} ({cname}): waiting={reason}")
        elif "terminated" in state and state["terminated"].get("exitCode", 0) != 0:
            code = state["terminated"].get("exitCode", 0)
            unhealthy.append(f"{ns}/{name} ({cname}): terminated exit={code}")

if unhealthy:
    print("; ".join(unhealthy))
' 2>/dev/null)"

  if [[ -z "$unhealthy_pods" ]]; then
    log_pass "Zero CrashLoopBackOff, Error, or Unhealthy pods detected across cluster"
  else
    log_fail "Unhealthy containers detected: ${unhealthy_pods}"
  fi
}

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
main() {
  echo ""
  echo -e "${C_CYAN}====================================================================${C_RESET}"
  echo -e "${C_CYAN}  HOMELAB AUTONOMOUS CLUSTER VERIFICATION SUITE${C_RESET}"
  echo -e "${C_CYAN}  Date: $(date)${C_RESET}"
  echo -e "${C_CYAN}====================================================================${C_RESET}"

  discover_endpoints

  if [[ "$WAIT_SYNC" == true ]]; then
    wait_for_flux_sync
  fi

  check_nodes
  check_core_infrastructure
  check_gitops_flux
  check_home_assistant
  check_minecraft
  check_storage_nfs
  check_monitoring_robusta
  check_pod_anomalies

  log_header "VERIFICATION SUMMARY"
  echo -e "Total Checks: ${TOTAL_TESTS}"
  echo -e "Passed:       ${C_GREEN}${PASSED_TESTS}${C_RESET}"
  echo -e "Failed:       ${C_RED}${FAILED_TESTS}${C_RESET}"

  if [[ "$FAILED_TESTS" -eq 0 ]]; then
    echo ""
    echo -e "${C_GREEN}>>> VERIFICATION SUCCESS: All homelab workloads and GitOps flows are 100% HEALTHY! <<<${C_RESET}"
    exit 0
  else
    echo ""
    echo -e "${C_RED}>>> VERIFICATION FAILED: Detected ${FAILED_TESTS} failure(s)! Remediation/Rollback required! <<<${C_RESET}"
    exit 1
  fi
}

main "$@"
