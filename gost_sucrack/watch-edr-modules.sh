#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 0) Basic settings
# ============================================================

LOG_FILE="/opt/vxagent/logs/agent.log"
CHECK_INTERVAL_SECONDS=10

REQUIRED_MODULES=(
  "account_blocker"
  "proc_terminator"
  "remote_shell"
  "quarantine"
  "correlator_linux"
  "endpoint_browser"
  "normalizer"
  "file_reader"
  "auditd_provisioner"
  "core"
)

# ============================================================
# 1) Input arguments
# ============================================================

if [[ "$#" -ne 1 ]]; then
  echo "ERROR: GROUP_ID argument is required" >&2
  exit 1
fi

GROUP_ID="$1"

if [[ -z "${GROUP_ID}" ]]; then
  echo "ERROR: GROUP_ID is empty" >&2
  exit 1
fi

# ============================================================
# 2) Get installed module names from agent log
# ============================================================

get_installed_modules() {
  if [[ ! -r "${LOG_FILE}" ]]; then
    return 0
  fi

  grep -F 'msg="initialized successfully"' "${LOG_FILE}" \
    | grep -F "group_id=${GROUP_ID}" \
    | sed -n 's/.*module_name=\([^ ]*\).*/\1/p' \
    | LC_ALL=C sort -u \
    || true
}

# ============================================================
# 3) Check all required modules
# ============================================================

all_modules_are_installed() {
  local installed_modules
  local required_module

  installed_modules="$(get_installed_modules)"

  for required_module in "${REQUIRED_MODULES[@]}"; do
    if ! grep -Fxq -- "${required_module}" <<< "${installed_modules}"; then
      return 1
    fi
  done

  return 0
}

# ============================================================
# 4) Actions after all modules are installed
# ============================================================

run_actions() {
  echo "All modules installed"
}

# ============================================================
# 5) Watch loop
# ============================================================

while true; do
  if all_modules_are_installed; then
    run_actions
    exit 0
  fi

  sleep "${CHECK_INTERVAL_SECONDS}"
done
