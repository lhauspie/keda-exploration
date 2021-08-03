#!/usr/bin/env bash

# This script expect you set env variable PGPASSWORD on your own to make it work without prompting.
echo "Running the sql script"
psql --host $PG_HOST \
     --port $PG_PORT \
     --username $PG_USERNAME \
     --dbname $PG_DATABASE \
     --file scripts/init.sql \
     --file scripts/make-it-clap.sql

echo "Everything's done"
