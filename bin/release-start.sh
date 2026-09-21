#!/bin/sh
set -eu
: "${DATABASE_PATH:=/data/catalogue.db}"
export DATABASE_PATH

# Fail closed on a fresh/missing volume. Populate a reviewed catalogue explicitly;
# normal restarts never copy a seed database or overwrite an existing database.
if [ ! -s "$DATABASE_PATH" ]; then
  echo 'Catalogue database missing. Explicit reviewed bootstrap on the attached volume is required.' >&2
  exit 1
fi

# Runs inside the volume-bearing Machine, never a Fly release_command Machine.
# Migration exceptions stop boot rather than serve an incompatible schema.
/app/bin/climb_ontario eval 'ClimbOntario.Release.migrate()'
exec /app/bin/climb_ontario start
