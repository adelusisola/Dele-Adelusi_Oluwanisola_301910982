#!/usr/bin/env bash
# Session A reads Adaeze's balance twice. Session B deposits 500 between the two reads.
source "$(dirname "$0")/lib.sh"
for level in "READ COMMITTED" "REPEATABLE READ"; do
  q -c "select reset_demo()" > /dev/null
  echo "--- session A runs at $level"
  q -At -v level="$level" <<'SQL' | sed 's/^/  A: /' &
BEGIN ISOLATION LEVEL :level;
SELECT 'first read  = ' || balance FROM account WHERE account_id = :adaeze;
DO $$ BEGIN PERFORM pg_sleep(2); END $$;
SELECT 'second read = ' || balance FROM account WHERE account_id = :adaeze;
COMMIT;
SQL
  ( sleep 1; q -At -c "update account set balance = balance + 500 where account_id = $ADAEZE; select 'B deposited 500 and committed'" | sed 's/^/  /' ) &
  wait
  echo
done
