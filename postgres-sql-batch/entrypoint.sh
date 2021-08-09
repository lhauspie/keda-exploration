#!/usr/bin/env bash

export JOB_NAME=${POD_NAME%-*}

# This script expect you set env variable PGPASSWORD on your own to make it work without prompting.
echo "Running the sql script"
psql --host $PG_HOST \
     --port $PG_PORT \
     --username $PG_USERNAME \
     --dbname $PG_DATABASE \
     --file scripts/init.sql \
     --file scripts/make-it-clap.sql

export EXIT_CODE=$?

if [ $EXIT_CODE = 0 ]
then
  echo "SUCCESS"
  exit $EXIT_CODE;
else
  echo "FAILURE"
  exit $EXIT_CODE;
fi
