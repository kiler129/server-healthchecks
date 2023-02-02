#!/usr/bin/env bash

cd /app

if [[ "${UPDATE_ON_START-0}" -eq 1 ]]; then
  echo "Updating all scripts..."
  /app/http-ping.sh -u
  /app/with-healthcheck.sh -u
  /app/http-middleware.sh -u
  echo "All updates finished, continuing startup"
fi

echo "Starting HTTP middleware with $@"
exec "$@"
