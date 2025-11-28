#!/usr/bin/env bash
set -euo pipefail

# Start script for SQLite "thought_database" container.
# This container should be launched with: bash start.sh
# It prepares the SQLite file and exits successfully (status 0).
# The optional Node.js db_visualizer is disabled by default and MUST NOT affect readiness.

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

# Guard optional db_visualizer behind an env flag; default OFF.
# To enable in a dev environment: set START_DB_VISUALIZER=1
if [ "${START_DB_VISUALIZER:-0}" = "1" ]; then
  if [ -d "db_visualizer" ]; then
    echo "[thought_database] START_DB_VISUALIZER=1 -> attempting optional db_visualizer start (non-blocking)..."
    bash db_visualizer_start_optional.sh || true
  else
    echo "[thought_database] db_visualizer directory not found. Skipping visualizer startup."
  fi
else
  echo "[thought_database] Optional db_visualizer disabled (START_DB_VISUALIZER not set to 1)."
fi

# Exit without keeping a process alive; this container's role is to prepare the DB file.
echo "[thought_database] Done."
# Always exit 0 on success. Any failure above exits non-zero explicitly.
exit 0
