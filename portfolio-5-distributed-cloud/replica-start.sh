#!/bin/bash
# Copies the primary on first start and then runs as a read-only standby
set -e
export PGPASSWORD=replicator_dev_password
if [ ! -s "$PGDATA/PG_VERSION" ]; then
  until pg_isready -h pg-primary -U vant; do sleep 1; done
  mkdir -p "$PGDATA" && chown postgres:postgres "$PGDATA" && chmod 700 "$PGDATA"
  gosu postgres pg_basebackup -h pg-primary -U replicator -D "$PGDATA" -R -X stream
fi
exec docker-entrypoint.sh postgres -c hot_standby=on
