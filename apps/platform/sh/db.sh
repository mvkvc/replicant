#! /bin/sh

ENGINE=podman

POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=platform_dev
DB_CONTAINER=platform_db
DB_IMAGE=docker.io/ankane/pgvector
DB_PATH=$(pwd)/.db/data

$ENGINE run --rm --replace --name $DB_CONTAINER \
  -p "$PLATFORM_DB_PORT":5432 \
  -e POSTGRES_USER=$POSTGRES_USER \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -e POSTGRES_DB=$POSTGRES_DB \
  -v $DB_PATH:/var/lib/postgresql/data \
  $DB_IMAGE
