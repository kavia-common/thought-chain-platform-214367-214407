#!/usr/bin/env bash
set -euo pipefail

# Start script for SQLite "thought_database" container.
# This container does not expose any TCP port. It prepares the SQLite file and exits successfully.

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
# Exit without keeping a process alive; this container's role is to prepare the DB file.
exit 0
