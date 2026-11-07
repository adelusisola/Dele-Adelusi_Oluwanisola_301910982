#!/usr/bin/env bash
# Rebuilds Portfolios 1 to 3 from scratch on the local PostgreSQL, in the right order, and stops if a check fails.
# Portfolios 4 and 5 use Docker: see their READMEs. Needs: PostgreSQL 18, and a database called vant_personal.
set -euo pipefail
cd "$(dirname "$0")"
psql -lqt | cut -d'|' -f1 | grep -qw vant_personal || createdb vant_personal
sql() { psql -X -q -v ON_ERROR_STOP=1 -d vant_personal "$@" 2>&1 | grep -v -E 'NOTICE|DETAIL: +drop cascades|^drop cascades' || true; }
P1=portfolio-1-database-design; P2=portfolio-2-query-optimisation; P3=portfolio-3-transactions-concurrency

echo "== Portfolio 1: schema and the 16 automatic checks"
sql -f $P1/Dele-Adelusi_Oluwanisola_301910982_schema.sql
out=$(psql -X -q -P pager=off -d vant_personal -f $P1/Dele-Adelusi_Oluwanisola_301910982_tests.sql)
echo "$out" | tail -4
echo "$out" | grep -q "ALL TESTS PASSED" || { echo "Portfolio 1 tests failed"; exit 1; }

echo; echo "== Portfolio 2: data, balance rules, plans and timings"
sql -f $P2/Dele-Adelusi_Oluwanisola_301910982_seed.sql
bad=$(psql -X -At -d vant_personal -f $P1/Dele-Adelusi_Oluwanisola_301910982_invariants.sql | awk -F'|' '{s += $2} END {print s + 0}')
[ "$bad" = 0 ] || { echo "a balance or transaction rule is violated"; exit 1; }
echo "balance and transaction rules: 0 violations"
(cd $P2 && ./Dele-Adelusi_Oluwanisola_301910982_run_plans.sh before > /dev/null && sql -f Dele-Adelusi_Oluwanisola_301910982_indexes.sql && ./Dele-Adelusi_Oluwanisola_301910982_run_plans.sh after > /dev/null && ./Dele-Adelusi_Oluwanisola_301910982_timings.sh && psql -X -q -P pager=off -d vant_personal -f Dele-Adelusi_Oluwanisola_301910982_index_overhead.sql | grep -v '^SET')

echo; echo "== Portfolio 3: demos"
sql -f $P3/Dele-Adelusi_Oluwanisola_301910982_setup.sql
ids=$(psql -X -At -d vant_personal -c "select string_agg(account_id::text, ' ' order by account_number) from vant.account where account_number in ('9000000001','9000000002')")
set -- $ids
(cd $P3 && psql -X -q -P pager=off -d vant_personal -v adaeze=$1 -v emeka=$2 -f Dele-Adelusi_Oluwanisola_301910982_01_commit_rollback.sql | grep -v '^$' && ./Dele-Adelusi_Oluwanisola_301910982_02_lost_update.sh && ./Dele-Adelusi_Oluwanisola_301910982_03_isolation.sh && ./Dele-Adelusi_Oluwanisola_301910982_04_deadlock.sh && ./Dele-Adelusi_Oluwanisola_301910982_05_idempotent_transfer.sh)
echo; echo "Done. Portfolios 4 and 5: see their READMEs."
