# thought_database (SQLite)

This container initializes and maintains a local SQLite database file for the application. SQLite is file-based and does not expose a TCP port.

Key points:
- No TCP port is used or exposed by the SQLite engine.
- Readiness is validated via file checks and by opening the database, not by probing a port.
- The backend should read the absolute file path from db_connection.txt or use the known path to connect.
- The container completes startup by initializing SQLite and then exiting with status 0 (no long-running process).

Files:
- myapp.db: the SQLite database file.
- init_db.py: idempotently creates the schema (including the required `thoughts` table) and writes connection info.
- test_db.py: verifies that the database file can be opened and queried.
- db_connection.txt: contains the absolute path and a `sqlite:///` connection string for consumers.
- start.sh: container entrypoint to initialize the DB and exit successfully (no running service).
- healthcheck.sh: returns success if the DB file is present and accessible.
- db_visualizer_start_optional.sh: best-effort helper for an optional Node-based viewer. It is disabled by default and never affects readiness or build success.

How readiness is determined:
- The healthcheck script checks only SQLite:
  1) myapp.db exists and is non-empty,
  2) a simple sqlite query succeeds (via test_db.py),
  3) db_connection.txt exists and includes a sqlite connection string.
- No Node.js, npm, or HTTP port checks are performed.

Optional: Database viewer (for local development only)
- A simple Node-based DB viewer exists under db_visualizer/. It serves HTTP (default port 3000) but is optional and NOT required for container readiness or builds.
- The visualizer is DISABLED by default during container startup and CI. It will not install Node modules or run unless explicitly enabled.
- To enable temporarily in a local dev environment, export `START_DB_VISUALIZER=1` and run `./start.sh` again. Failures are logged and ignored; readiness is unaffected.

Manual usage of the optional viewer (opt-in):
- Ensure Node.js and npm are installed in your local environment (not required for builds/CI).
- From the `thought_database` directory:
  - Source the SQLite path env: `source db_visualizer/sqlite.env`
  - Start viewer best-effort: `START_DB_VISUALIZER=1 bash db_visualizer_start_optional.sh`
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
