#!/bin/sh
set -eu

if [ "$DATABASE" = "postgres" ]
then
    echo "Waiting for postgres..."

    while ! nc -z "${SQL_HOST}" "${SQL_PORT}"; do
      sleep 1
    done

    echo "PostgreSQL started"
fi

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  python manage.py migrate

  if [ "${LOAD_INITIAL_DATA:-false}" = "true" ]; then
    python manage.py loaddata initial_data.json
  fi
fi
# Ejecucion de Gunicorn
exec "$@"

# Idem a bash
# gunicorn core.wsgi:application \
#  --bind 0.0.0.0:8000 \
#  --workers 3 \
#  --timeout 60
