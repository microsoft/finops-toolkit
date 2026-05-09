#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# deploy.sh — single entry point for SRE Agent deployment
#
# Dry-run is the default. Pass --execute to deploy for real.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── defaults ───────────────────────────────────────────────
MODE="dry-run"
RECIPE=""
FINOPS_HUB_CLUSTER_URI=""
SECRETS=""
OUTPUT=""

usage() {
  cat <<EOF
Usage: $(basename "$0") <recipe-directory> [options]

Deploys an Azure SRE Agent from a recipe directory.

  Dry-run is the default. Use --execute to deploy for real.

Options:
  --execute                     Actually deploy (default is dry-run)
  --finops-hub-cluster-uri URI  FinOps Hub Kusto cluster URI
  --secrets FILE                Connector secrets env file
  --output PREFIX               Output prefix for generated files
  -h, --help                    Show this help

Examples:
  # Preview what would happen (dry-run):
  bash bin/deploy.sh recipes/finops-hub/

  # Deploy for real:
  bash bin/deploy.sh recipes/finops-hub/ --execute

  # Deploy with FinOps Hub Kusto connector:
  bash bin/deploy.sh recipes/finops-hub/ --execute \\
   --finops-hub-cluster-uri https://mycluster.eastus2.kusto.windows.net
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --execute)                    MODE="execute"; shift ;;
    --finops-hub-cluster-uri)     FINOPS_HUB_CLUSTER_URI="$2"; shift 2 ;;
    --secrets)                    SECRETS="$2"; shift 2 ;;
    --output)                     OUTPUT="$2"; shift 2 ;;
    -h|--help)                    usage 0 ;;
    -*)                           echo "Unknown option: $1" >&2; usage 1 ;;
    *)                            RECIPE="$1"; shift ;;
  esac
done

[ -n "$RECIPE" ] || { echo "Error: recipe directory required." >&2; usage 1; }
[ -d "$RECIPE" ] || { echo "Error: recipe directory not found: $RECIPE" >&2; exit 1; }

# ─── validate + export FinOps Hub cluster URI ──────────────
if [ -n "$FINOPS_HUB_CLUSTER_URI" ]; then
  FINOPS_HUB_CLUSTER_URI="${FINOPS_HUB_CLUSTER_URI%/}"
  [[ "$FINOPS_HUB_CLUSTER_URI" == https://* ]] || { echo "Error: --finops-hub-cluster-uri must use https:// — got: $FINOPS_HUB_CLUSTER_URI" >&2; exit 1; }
  # Reject URIs with a path after the hostname (e.g. .../Hub) — database is set per-tool, not in the connector URI
  _host="${FINOPS_HUB_CLUSTER_URI#https://}"
  [[ "$_host" != */* ]] || { echo "Error: URI should be a cluster endpoint (e.g. https://mycluster.eastus2.kusto.windows.net) — do not include a database path." >&2; exit 1; }
  [[ "$FINOPS_HUB_CLUSTER_URI" == *kusto.windows.net ]] || echo "Warning: URI doesn't match *.kusto.windows.net — $FINOPS_HUB_CLUSTER_URI" >&2
  export FINOPS_HUB_CLUSTER_URI
fi

# ─── resolve subscription from current az context ──────────
SUB="$(az account show --query id -o tsv)"
SUB_NAME="$(az account show --query name -o tsv)"
TENANT="$(az account show --query tenantId -o tsv)"

echo "═══════════════════════════════════════════════════════════"
echo "  SRE Agent deployment"
echo "  Mode:         ${MODE}"
echo "  Subscription: ${SUB_NAME} (${SUB})"
echo "  Tenant:       ${TENANT}"
echo "  Recipe:       ${RECIPE}"
[ -n "$FINOPS_HUB_CLUSTER_URI" ] && echo "  FinOps Hub:   ${FINOPS_HUB_CLUSTER_URI}"
echo "═══════════════════════════════════════════════════════════"

if [ "$MODE" = "dry-run" ]; then
  echo ""
  echo "  *** DRY-RUN MODE — no resources will be created or modified ***"
  echo "  *** Pass --execute to deploy for real                       ***"
  echo ""
fi

# ─── step 1: assemble recipe into parameters + extras ──────
echo "── Step 1: Assembling recipe ──────────────────────────────"
ASSEMBLE_ARGS=("$RECIPE")
[ -n "$SECRETS" ] && ASSEMBLE_ARGS+=(--secrets "$SECRETS")
[ -n "$OUTPUT" ]  && ASSEMBLE_ARGS+=(--output "$OUTPUT")
bash "$ROOT/bicep/assemble-agent.sh" "${ASSEMBLE_ARGS[@]}"

PREFIX="${OUTPUT:-$RECIPE}"
PARAMS_FILE="${PREFIX}.parameters.json"
EXTRAS_FILE="${PREFIX}.extras.json"

[ -f "$PARAMS_FILE" ] || { echo "Error: assemble did not produce $PARAMS_FILE" >&2; exit 1; }
[ -f "$EXTRAS_FILE" ] || { echo "Error: assemble did not produce $EXTRAS_FILE" >&2; exit 1; }

# ─── read identity from generated params ───────────────────
AGENT_NAME="$(jq -r '.parameters.agentName.value' "$PARAMS_FILE")"
AGENT_RG="$(jq -r '.parameters.agentResourceGroupName.value' "$PARAMS_FILE")"
LOCATION="$(jq -r '.parameters.location.value' "$PARAMS_FILE")"

echo ""
echo "  Agent:    ${AGENT_NAME}"
echo "  RG:       ${AGENT_RG}"
echo "  Location: ${LOCATION}"
echo ""

# ─── step 2: bicep deployment ─────────────────────────────
echo "── Step 2: Bicep deployment ───────────────────────────────"

if [ "$MODE" = "dry-run" ]; then
  echo "[dry-run] Running: az deployment sub what-if"
  az deployment sub what-if \
    --location "$LOCATION" \
    --template-file "$ROOT/bicep/main.bicep" \
    --parameters "@${PARAMS_FILE}" \
    --no-pretty-print 2>&1 | head -80
  echo ""
  echo "[dry-run] Full what-if output truncated. Re-run with --execute to deploy."
else
  echo "Running: az deployment sub create"
  az deployment sub create \
    --location "$LOCATION" \
    --name "sre-agent-${AGENT_NAME}-$(date +%Y%m%d%H%M%S)" \
    --template-file "$ROOT/bicep/main.bicep" \
    --parameters "@${PARAMS_FILE}"
fi

# ─── step 3: apply extras ─────────────────────────────────
echo ""
echo "── Step 3: Apply extras ───────────────────────────────────"

EXTRAS_ARGS=("$SUB" "$AGENT_RG" "$AGENT_NAME" "$EXTRAS_FILE")

if [ "$MODE" = "dry-run" ]; then
  bash "$ROOT/bicep/apply-extras.sh" --dry-run "${EXTRAS_ARGS[@]}"
else
  bash "$ROOT/bicep/apply-extras.sh" "${EXTRAS_ARGS[@]}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
if [ "$MODE" = "dry-run" ]; then
  echo "  DRY-RUN COMPLETE — no changes made."
  echo "  Re-run with --execute to deploy for real."
else
  echo "  DEPLOYMENT COMPLETE"
  echo "  Agent: ${AGENT_NAME} in ${AGENT_RG}"
  echo "  Portal: https://sre.azure.com"
fi
echo "═══════════════════════════════════════════════════════════"
