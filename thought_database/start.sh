#!/usr/bin/env bash
set -euo pipefail

# Start script for SQLite "thought_database" container.
# This container does not expose any TCP port. It prepares the SQLite file and exits successfully.
# The optional Node.js db_visualizer is best-effort and MUST NOT affect readiness.

echo "[thought_database] Starting initialization..."
# Ensure python is available; fallback error if not
if ! command -v python3 >/dev/null 2>&1; then
  echo "[thought_database] ERROR: python3 not found in PATH." >&2
  exit 1
fi

# Initialize DB (idempotent)
python3 init_db.py

# Basic readiness check by opening the DB
if ! python3 test_db.py; then
  echo "[thought_database] ERROR: SQLite readiness test failed." >&2
  exit 1
fi

echo "[thought_database] Initialization complete. SQLite database is ready as a file (no TCP port)."

# Optionally attempt to start the db_visualizer in best-effort mode (non-blocking).
# This should never cause the container to fail.
if [ -d "db_visualizer" ]; then
  echo "[thought_database] Attempting to start optional db_visualizer..."
  bash db_visualizer_start_optional.sh || true
else
  echo "[thought_database] db_visualizer directory not found. Skipping visualizer startup."
fi

# Exit without keeping a process alive; this container's role is to prepare the DB file.
echo "[thought_database] Done."
exit 0
