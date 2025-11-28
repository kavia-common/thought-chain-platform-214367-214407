# thought-chain-platform-214367-214407

Note for CI/platform:
- The thought_database container is SQLite-only and has no long-running process.
- Always start it with: bash thought_database/start.sh
- Do NOT cd into thought_database/db_visualizer or run npm start by default; the visualizer is optional and disabled unless START_DB_VISUALIZER=1 is set explicitly.