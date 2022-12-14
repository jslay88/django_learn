#!/bin/sh -l

set -e

if [ -f '.env' ]; then
  . '.env'
fi

echo "Using $(python3 --version 2>&1) located at $(which python3)"

# Do first-time set up of the database if necessary
if [ ! -z "$RUN_MIGRATIONS" ]; then
  # Wait for the database to be ready for initialization tasks
  until pg_isready --host="${PGHOST:-localhost}" --port="${PGPORT:-5432}"
  do
    echo "Waiting for postgres at: ${PGHOST:-localhost}:${PGPORT:-5432}"
    sleep 1;
  done

  # Check the DB if it needs refresh or migrations (initial-data.sh)
  if ! psql "postgres://${PGUSER:-postgres}:${PGPASSWORD:-postgres}@${PGHOST:-localhost}:${PGPORT:-5432}/${PGDATABASE:-postgres}" -c 'SELECT COUNT(*) FROM auth_user' >/dev/null 2>&1 || [ ! -z $FORCE_DB_REBUILD ]; then
    echo "Doing first-time database and search index setup..."
    if [ -n "$DB_DUMP_FILE" ] || [ -n "$DB_DUMP_URL" ]; then
      echo "Running refresh-data.sh... $DB_DUMP_FILE"
      ./refresh-data.sh "$DB_DUMP_FILE"
      echo "Create the cache table..."
      ./$APP_NAME/manage.py createcachetable

      # refresh-data.sh runs migrations,
      # unset vars to prevent further action
      unset RUN_MIGRATIONS
    else
      # Detected the database is empty, or force rebuild was requested,
      # but we have no valid data sources to load data.
      echo "WARNING: Database rebuild request detected, but missing DB_DUMP_URL/DB_DUMP_FILE variable (one or the other is needed). Unable to load data!!"
    fi
  else
    echo "Data detected, FORCE_DB_REBUILD not requested. Skipping data load!"
  fi

  # Check if we still need to run migrations, if so, run them
  if [ ! -z $RUN_MIGRATIONS ]; then
    echo "Running migrations..."
    python $APP_NAME/manage.py migrate --noinput --fake-initial
  fi
fi

# Execute the Docker CMD
exec "$@"
