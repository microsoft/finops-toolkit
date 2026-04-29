#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$(cd "${TEST_DIR}/.." && pwd)/post-provision.sh"
WORKDIR="$(mktemp -d)"
TEST_REPO="${WORKDIR}/repo"
BIN_DIR="${WORKDIR}/bin"
STDOUT_FILE="${WORKDIR}/stdout.log"
STDERR_FILE="${WORKDIR}/stderr.log"
SRECTL_FAIL_LOG="${WORKDIR}/srectl.fail.log"
AZ_FAIL_LOG="${WORKDIR}/az.fail.log"

cleanup() {
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [ "${expected}" != "${actual}" ]; then
    fail "${message} (expected: ${expected}, actual: ${actual})"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! grep -Eqi "${pattern}" "${file}"; then
    fail "${message}"
  fi
}

assert_empty() {
  local file="$1"
  local message="$2"
  if [ -s "${file}" ]; then
    printf 'Unexpected contents of %s:\n' "${file}" >&2
    cat "${file}" >&2
    fail "${message}"
  fi
}

mkdir -p \
  "${TEST_REPO}/scripts" \
  "${TEST_REPO}/sre-config/skills/example-skill" \
  "${TEST_REPO}/sre-config/agents" \
  "${TEST_REPO}/sre-config/knowledge" \
  "${TEST_REPO}/sre-config/scheduled-tasks" \
  "${TEST_REPO}/tools" \
  "${BIN_DIR}"

cp "${SOURCE_SCRIPT}" "${TEST_REPO}/scripts/post-provision.sh"
chmod +x "${TEST_REPO}/scripts/post-provision.sh"

cat <<'EOF' > "${TEST_REPO}/sre-config/skills/example-skill/README.md"
# Example skill
Dry-run fixture for post-provision.sh.
EOF

cat <<'EOF' > "${TEST_REPO}/sre-config/agents/example-agent.yaml"
name: example-agent
description: Dry-run fixture
EOF

cat <<'EOF' > "${TEST_REPO}/tools/example-tool.yaml"
name: example-tool
description: Dry-run fixture
EOF

cat <<'EOF' > "${TEST_REPO}/sre-config/knowledge/example.md"
# Example knowledge
Dry-run fixture for knowledge upload.
EOF

cat <<'EOF' > "${TEST_REPO}/sre-config/scheduled-tasks/example-task.yaml"
name: example-task
prompt: Run the dry-run fixture.
EOF

: > "${SRECTL_FAIL_LOG}"
: > "${AZ_FAIL_LOG}"

cat <<EOF > "${BIN_DIR}/srectl"
#!/usr/bin/env bash
printf 'srectl invoked during dry-run: %s\n' "\$*" >> "${SRECTL_FAIL_LOG}"
printf 'mock srectl should not be invoked during dry-run\n' >&2
exit 1
EOF

cat <<EOF > "${BIN_DIR}/az"
#!/usr/bin/env bash
printf 'az invoked during dry-run: %s\n' "\$*" >> "${AZ_FAIL_LOG}"
printf 'mock az should not be invoked during dry-run\n' >&2
exit 1
EOF

chmod +x "${BIN_DIR}/srectl" "${BIN_DIR}/az"

set +e
(
  export PATH="${BIN_DIR}:${PATH}"
  export SRE_AGENT_ENDPOINT='https://fake.azuresre.ai'
  bash "${TEST_REPO}/scripts/post-provision.sh" --dry-run
) > "${STDOUT_FILE}" 2> "${STDERR_FILE}"
EXIT_CODE=$?
set -e

assert_eq 0 "${EXIT_CODE}" 'post-provision.sh --dry-run should exit 0'
assert_contains "${STDOUT_FILE}" '^\[DRY-RUN\]' 'stdout should contain [DRY-RUN] prefixed lines'
assert_contains "${STDOUT_FILE}" '\[DRY-RUN\].*skill' 'stdout should log at least one skill dry-run line'
assert_contains "${STDOUT_FILE}" '\[DRY-RUN\].*agent' 'stdout should log at least one agent dry-run line'
assert_contains "${STDOUT_FILE}" '\[DRY-RUN\].*tool' 'stdout should log at least one tool dry-run line'
assert_contains "${STDOUT_FILE}" '\[DRY-RUN\].*knowledge' 'stdout should log at least one knowledge dry-run line'
assert_contains "${STDOUT_FILE}" '\[DRY-RUN\].*scheduled task' 'stdout should log at least one scheduled task dry-run line'
assert_empty "${SRECTL_FAIL_LOG}" 'srectl must not be invoked during dry-run'
assert_empty "${AZ_FAIL_LOG}" 'az must not be invoked during dry-run'

printf 'PASS: post-provision.sh dry-run contract satisfied\n'
