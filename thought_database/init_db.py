#!/usr/bin/env python3
"""Initialize SQLite database for thought_database.

This script is idempotent:
- Creates required tables if they do not exist (including the PRD-required 'thoughts' table).
- Writes the absolute database path and connection string to db_connection.txt for backend consumption.
- Optionally verifies that the 'thoughts' table exists after creation.
"""

import os
import sqlite3
from typing import Tuple

DB_NAME = "myapp.db"  # SQLite database file name


def _ensure_conn() -> Tuple[sqlite3.Connection, sqlite3.Cursor]:
    """Create a connection and cursor with safe pragmas."""
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    # Enable foreign keys for safety if ever used
    cursor.execute("PRAGMA foreign_keys = ON")
    return conn, cursor


def _init_core_tables(cursor: sqlite3.Cursor) -> None:
    """Create required and demo tables if they do not exist."""
    # PRD-required table: thoughts
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS thoughts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL,
          thought_text TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Keep/ignore demo tables, but ensure idempotency
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS app_info (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            value TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Additive, idempotent performance indexes (do not change schema/behavior)
    # Index to accelerate chronological scans (e.g., GET /thoughts ordered by created_at)
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_thoughts_created_at
        ON thoughts (datetime(created_at))
    """)
    # Composite index to accelerate per-user daily checks and ordered fetches
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_thoughts_user_created
        ON thoughts (username, datetime(created_at))
    """)


def _seed_app_info(cursor: sqlite3.Cursor) -> None:
    """Seed minimal app_info metadata idempotently."""
    cursor.execute(
        "INSERT OR REPLACE INTO app_info (id, key, value) VALUES (?, ?, ?)",
        (1, "project_name", "thought_database"),
    )
    cursor.execute(
        "INSERT OR REPLACE INTO app_info (id, key, value) VALUES (?, ?, ?)",
        (2, "version", "0.1.0"),
    )
    cursor.execute(
        "INSERT OR REPLACE INTO app_info (id, key, value) VALUES (?, ?, ?)",
        (3, "author", "John Doe"),
    )
    cursor.execute(
        "INSERT OR REPLACE INTO app_info (id, key, value) VALUES (?, ?, ?)",
        (4, "description", ""),
    )


def _write_connection_info(db_abs_path: str) -> None:
    """Write absolute DB path and connection string to db_connection.txt."""
    connection_string = f"sqlite:///{db_abs_path}"
    try:
        with open("db_connection.txt", "w") as f:
            f.write("# SQLite connection methods:\n")
            f.write(f"# Python: sqlite3.connect('{db_abs_path}')\n")
            f.write(f"# Connection string: {connection_string}\n")
            f.write(f"# File path: {db_abs_path}\n")
        print("Connection information saved to db_connection.txt")
    except Exception as e:
        print(f"Warning: Could not save connection info: {e}")


def _write_visualizer_env(db_abs_path: str) -> None:
    """Write sqlite env file for the local visualizer."""
    if not os.path.exists("db_visualizer"):
        os.makedirs("db_visualizer", exist_ok=True)
        print("Created db_visualizer directory")
    try:
        with open("db_visualizer/sqlite.env", "w") as f:
            f.write(f'export SQLITE_DB="{db_abs_path}"\n')
        print("Environment variables saved to db_visualizer/sqlite.env")
    except Exception as e:
        print(f"Warning: Could not save environment variables: {e}")


def _verify_thoughts_table(cursor: sqlite3.Cursor) -> bool:
    """Check that the thoughts table exists."""
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='thoughts'"
    )
    return cursor.fetchone() is not None


def main() -> None:
    """Entry point to idempotently initialize the database."""
    print("Starting SQLite setup...")

    db_exists = os.path.exists(DB_NAME)
    if db_exists:
        print(f"SQLite database already exists at {DB_NAME}")
        try:
            conn, cursor = _ensure_conn()
            cursor.execute("SELECT 1")
            conn.close()
            print("Database is accessible and working.")
        except Exception as e:
            print(f"Warning: Database exists but may be corrupted: {e}")
    else:
        print("Creating new SQLite database...")

    # Initialize and verify schema
    conn, cursor = _ensure_conn()
    try:
        _init_core_tables(cursor)
        _seed_app_info(cursor)
        conn.commit()

        # Optional verification
        if _verify_thoughts_table(cursor):
            print("Verified: 'thoughts' table is present.")
        else:
            print("Error: 'thoughts' table verification failed.")

        # Brief confirmation logs for indexes
        try:
            cursor.execute("SELECT name FROM sqlite_master WHERE type='index' AND name IN ('idx_thoughts_created_at','idx_thoughts_user_created')")
            idxs = {row[0] for row in cursor.fetchall()}
            if 'idx_thoughts_created_at' in idxs:
                print("Index ready: idx_thoughts_created_at on datetime(created_at)")
            if 'idx_thoughts_user_created' in idxs:
                print("Index ready: idx_thoughts_user_created on (username, datetime(created_at))")
        except Exception as _e:
            # Non-fatal: indexing is optional optimization
            print("Note: Skipped index verification (non-fatal).")
    finally:
        # Gather stats before closing
        try:
            cursor.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
            table_count = cursor.fetchone()[0]
        except Exception:
            table_count = 0
        try:
            cursor.execute("SELECT COUNT(*) FROM app_info")
            record_count = cursor.fetchone()[0]
        except Exception:
            record_count = 0
        conn.close()

    # Persist connection info for backend consumption
    db_abs_path = os.path.abspath(DB_NAME)
    _write_connection_info(db_abs_path)
    _write_visualizer_env(db_abs_path)

    # Output summary
    print("\nSQLite setup complete!")
    print(f"Database: {DB_NAME}")
    print(f"Location: {db_abs_path}\n")

    print("To use with Node.js viewer, run: source db_visualizer/sqlite.env")

    connection_string = f"sqlite:///{db_abs_path}"
    print("\nTo connect to the database, use one of the following methods:")
    print(f"1. Python: sqlite3.connect('{db_abs_path}')")
    print(f"2. Connection string: {connection_string}")
    print(f"3. Direct file access: {db_abs_path}")
    print("")

    print("Database statistics:")
    print(f"  Tables: {table_count}")
    print(f"  App info records: {record_count}")

    # If sqlite3 CLI is available, show how to use it
    try:
        import subprocess
        result = subprocess.run(['which', 'sqlite3'], capture_output=True, text=True)
        if result.returncode == 0:
            print("")
            print("SQLite CLI is available. You can also use:")
            print(f"  sqlite3 {db_abs_path}")
    except Exception:
        pass

    # Exit successfully
    print("\nScript completed successfully.")


if __name__ == "__main__":
    main()
