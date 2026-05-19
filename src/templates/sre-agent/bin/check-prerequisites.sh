#!/usr/bin/env bash
# check-prerequisites.sh — verify required tools are installed

usage() {
  cat <<EOF
Usage: $0 [--subscription <id>]

Options:
  --subscription <id>  Subscription to scope Azure CLI checks
  -h, --help           Show this help
EOF
  exit "${1:-0}"
}

check_prerequisites() {
  local missing=0

  for cmd in az jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "  ❌ Missing: $cmd" >&2
      missing=$((missing + 1))
    fi
  done

  if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
    echo "  ❌ Missing: python3 (needed for YAML processing)" >&2
    missing=$((missing + 1))
  else
    local py=$(command -v python3 || command -v python)
    if ! "$py" -c "import yaml" 2>/dev/null; then
      echo "  ❌ Missing: PyYAML — install: pip install pyyaml" >&2
      missing=$((missing + 1))
    fi
  fi

  if ! command -v curl &>/dev/null; then
    echo "  ❌ Missing: curl" >&2
    missing=$((missing + 1))
  fi

  if [[ $missing -gt 0 ]]; then
    echo "  $missing prerequisite(s) missing. See README for install guide." >&2
    return 1
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  SUBSCRIPTION_ID=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --subscription)
        [[ -n "${2:-}" && "${2:-}" != -* ]] || { echo "Error: flag --subscription requires a value" >&2; exit 2; }
        SUBSCRIPTION_ID="$2"
        shift 2
        ;;
      -h|--help)
        usage 0
        ;;
      *)
        echo "Error: unexpected argument '$1'" >&2
        usage 2
        ;;
    esac
  done

  if [[ -n "$SUBSCRIPTION_ID" ]]; then
    export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
  fi

  check_prerequisites
fi
