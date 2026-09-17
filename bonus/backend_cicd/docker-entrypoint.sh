#!/bin/bash

#means exit immediately if any command fails.
set -e

echo "[entrypoint] Applying database migrations (alembic upgrade head)"

attempt=0
max_attempts=10

#alembic upgrade head applies all pending database migrations to bring your database schema up to the latest version.
until alembic upgrade head; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "[entrypoint] Failed to apply database migrations after $attempt attempts. Exiting."
        exit 1
    fi
    echo "[entrypoint] Database not ready yet. Retrying in 5 seconds... (Attempt: $attempt)"
    sleep 5
done

echo "[entrypoint] Migration complete. Starting: $*"
exec "$@"