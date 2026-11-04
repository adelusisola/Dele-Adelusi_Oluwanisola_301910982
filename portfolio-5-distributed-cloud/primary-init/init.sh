#!/bin/bash
# Runs once when the primary is first created: replication user, the Portfolio 1 schema and two demo accounts
set -e
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q <<SQL
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_dev_password';
SQL
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q -f /schema.sql > /dev/null 2>&1
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q <<SQL
INSERT INTO vant.customer (full_name, email, phone, date_of_birth) VALUES ('Demo Adaeze', 'adaeze@demo.example.com', '09000000001', '1990-01-01');
INSERT INTO vant.account (customer_id, account_number, type, currency, balance) VALUES (1, '9000000001', 'WALLET', 'NGN', 1000);
SQL
