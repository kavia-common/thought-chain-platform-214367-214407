# thought_database (SQLite)

This container initializes and maintains a local SQLite database file for the application. SQLite is file-based and does not expose a TCP port.

Key points:
- No TCP port is used or exposed by the SQLite engine.
- Readiness is validated via file checks and by opening the database, not by probing a port.
- The backend should read the absolute file path from db_connection.txt or use the known path to connect.

Files:
- myapp.db: the SQLite database file.
- init_db.py: idempotently creates the schema (including the required `thoughts` table) and writes connection info.
- test_db.py: verifies that the database file can be opened and queried.
- db_connection.txt: contains the absolute path and a `sqlite:///` connection string for consumers.
- start.sh: container entrypoint to initialize the DB and exit successfully (no running service).
- healthcheck.sh: returns success if the DB file is present and accessible.

How readiness is determined:
- The healthcheck script checks:
  1) myapp.db exists and is non-empty,
  2) a simple sqlite query succeeds (via test_db.py),
  3) db_connection.txt exists and includes a sqlite connection string.

Optional: Database viewer (for local development)
- A simple Node-based DB viewer exists under db_visualizer/. It serves HTTP (default port 3000) but is optional and not required for container readiness.

Backend integration:
- The absolute path to the database is written by init_db.py to db_connection.txt as a `sqlite:///...` connection string.
- Ensure the backend uses this path or an environment variable pointing to the same path.
