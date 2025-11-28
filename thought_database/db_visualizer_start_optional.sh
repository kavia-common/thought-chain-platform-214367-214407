#!/usr/bin/env bash
set -euo pipefail

# Optional db_visualizer bootstrapper.
# - Installs Node dependencies if package.json exists.
# - Starts the visualizer only when explicitly enabled and dependencies resolve.
# - Never exits non-zero; errors are logged and ignored.
# - Requires START_DB_VISUALIZER=1 to proceed.
# - Uses npm run start:optional to avoid direct node server.js invocations.

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

# Do not attempt to run from inside the visualizer folder during builds
if [ "$(basename "$(pwd)")" = "db_visualizer" ]; then
  echo "[db_visualizer] Running inside db_visualizer directory; refusing to start to avoid CI auto-start." | tee -a "${LOG_FILE}" || true
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

install_dependencies() {
  echo "[db_visualizer] Installing dependencies..." | tee -a "${LOG_FILE}" || true
  rm -rf node_modules package-lock.json 2>/dev/null || true
  # Use npm ci if lockfile exists, else npm install
  if [ -f package-lock.json ]; then
    npm ci --legacy-peer-deps >> "${LOG_FILE}" 2>&1 || true
  else
    npm install --no-audit --no-fund --legacy-peer-deps >> "${LOG_FILE}" 2>&1 || true
  fi
}

install_dependencies

# Verify express resolves
if ! node -e "require.resolve('express')" >/dev/null 2>&1; then
  echo "[db_visualizer] express not resolvable after install. Skipping visualizer start." | tee -a "${LOG_FILE}" || true
  popd >/dev/null || true
  finish_ok
fi

# Start the server in background; don't fail container if it crashes
echo "[db_visualizer] Starting server in background via npm run start:optional..." | tee -a "${LOG_FILE}" || true
nohup npm run start:optional >> "${LOG_FILE}" 2>&1 & disown || true

popd >/dev/null || true
finish_ok
