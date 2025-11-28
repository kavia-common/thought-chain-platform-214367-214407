#!/usr/bin/env bash
set -euo pipefail

# Optional db_visualizer bootstrapper.
# - Installs Node dependencies if package.json exists.
# - Tries to pin a known-good express version if install issues happen.
# - Starts the visualizer in the background only if 'node' and 'npm' are available.
# - Never exits non-zero; errors are logged and ignored.
# - Additional guard: requires START_DB_VISUALIZER=1 to proceed at all.

VIS_DIR="db_visualizer"
LOG_FILE="${VIS_DIR}/visualizer.log"

finish_ok() {
  echo "[db_visualizer] Optional visualizer step completed (best-effort)."
  exit 0
}

# Require explicit opt-in
if [ "${START_DB_VISUALIZER:-0}" != "1" ]; then
  echo "[db_visualizer] START_DB_VISUALIZER not set to 1. Skipping."
  finish_ok
fi

echo "[db_visualizer] Optional startup beginning..."

# Preconditions: node & npm available?
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "[db_visualizer] Node or npm not found. Skipping visualizer." | tee -a "${LOG_FILE}" || true
  finish_ok
fi

# Must have a package.json to proceed
if [ ! -f "${VIS_DIR}/package.json" ]; then
  echo "[db_visualizer] package.json not found. Skipping visualizer." | tee -a "${LOG_FILE}" || true
  finish_ok
fi

pushd "${VIS_DIR}" >/dev/null || finish_ok

# Ensure express dependency is pinned to a compatible version to avoid legacy "Cannot find module ./lib/express" issues.
# The included package.json uses ^4.18.2 which should be fine. We explicitly set it if missing or broken.
ensure_dependencies() {
  echo "[db_visualizer] Installing dependencies..." | tee -a "${LOG_FILE}" || true
  # Clean previous node_modules if corrupted
  rm -rf node_modules package-lock.json 2>/dev/null || true
  # Install with legacy-peer-deps to avoid conflicts in constrained environments
  if ! npm ci --legacy-peer-deps >> "${LOG_FILE}" 2>&1; then
    echo "[db_visualizer] npm ci failed, attempting npm install..." | tee -a "${LOG_FILE}" || true
    if ! npm install --no-audit --no-fund --legacy-peer-deps >> "${LOG_FILE}" 2>&1; then
      echo "[db_visualizer] npm install failed. Trying to explicitly install express@4 ..." | tee -a "${LOG_FILE}" || true
      npm install express@4 --no-audit --no-fund --legacy-peer-deps >> "${LOG_FILE}" 2>&1 || true
    fi
  fi
}

ensure_dependencies

# Verify express resolves
if ! node -e "require.resolve('express')" >/dev/null 2>&1; then
  echo "[db_visualizer] express not resolvable after install. Skipping visualizer start." | tee -a "${LOG_FILE}" || true
  popd >/dev/null || true
  finish_ok
fi

# Start the server in background; don't fail container if it crashes
echo "[db_visualizer] Starting server in background..." | tee -a "${LOG_FILE}" || true
# Use nohup to detach; redirect output to log
nohup npm run start >> "${LOG_FILE}" 2>&1 & disown || true

popd >/dev/null || true
finish_ok
