#!/usr/bin/env bash
# Compatibility wrapper. The SRE Agent recipe now follows the upstream
# Bicep + apply-extras pattern and no longer uses srectl for post-provisioning.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "bin/post-provision.sh is deprecated; forwarding to bin/apply-extras.sh" >&2
exec bash "${SCRIPT_DIR}/apply-extras.sh" "$@"
