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
- db_visualizer_start_optional.sh: best-effort helper to install and start the optional Node-based database viewer without impacting readiness.

How readiness is determined:
- The healthcheck script checks:
  1) myapp.db exists and is non-empty,
  2) a simple sqlite query succeeds (via test_db.py),
  3) db_connection.txt exists and includes a sqlite connection string.

Optional: Database viewer (for local development)
- A simple Node-based DB viewer exists under db_visualizer/. It serves HTTP (default port 3000) but is optional and NOT required for container readiness.
- The visualizer is disabled by default during container startup. To start it manually (best-effort), set `START_DB_VISUALIZER=1` and run `start.sh`, or run `bash db_visualizer_start_optional.sh` directly from the `thought_database` directory. Failures are logged and ignored.

Manual usage of the optional viewer:
- Ensure Node.js and npm are installed in the environment.
- From the `thought_database` directory:
  - Source the SQLite path env: `source db_visualizer/sqlite.env`
  - Start viewer best-effort: `bash db_visualizer_start_optional.sh`
  - Or manually:
    ```
    cd db_visualizer
    npm ci --legacy-peer-deps || npm install --no-audit --no-fund --legacy-peer-deps
    npm run start
    ```
  - Open http://localhost:3000

Backend integration:
- The absolute path to the database is written by init_db.py to db_connection.txt as a `sqlite:///...` connection string.
- Ensure the backend uses this path or an environment variable pointing to the same path.
