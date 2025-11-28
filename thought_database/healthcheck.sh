#!/usr/bin/env bash
set -euo pipefail

DB_FILE="myapp.db"
CONN_INFO_FILE="db_connection.txt"

# 1) Check DB file exists and is non-empty
if [ ! -s "${DB_FILE}" ]; then
  echo "Health: missing or empty ${DB_FILE}"
  exit 1
fi

# 2) Check that we can connect and query sqlite version via test_db.py
if ! python3 test_db.py >/dev/null 2>&1; then
  echo "Health: sqlite connection test failed"
  exit 1
fi

# 3) Ensure connection info file exists with sqlite:/// prefix
if [ ! -f "${CONN_INFO_FILE}" ]; then
  echo "Health: missing ${CONN_INFO_FILE}"
  exit 1
fi
if ! grep -q "sqlite:///" "${CONN_INFO_FILE}"; then
  echo "Health: ${CONN_INFO_FILE} missing sqlite connection string"
  exit 1
fi

echo "OK"
exit 0
