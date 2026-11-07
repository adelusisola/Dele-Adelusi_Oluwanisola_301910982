#!/usr/bin/env bash
# Usage: ./Dele-Adelusi_Oluwanisola_301910982_run_plans.sh before|after. Runs each query 5 times, keeps the last plan and records all 5 execution times.
phase=$1; mkdir -p plans/$phase; : > plans/$phase/Dele-Adelusi_Oluwanisola_301910982_times.csv
export PGOPTIONS="-c search_path=vant"
psql -d vant_personal -qc "VACUUM ANALYZE"
for f in queries/*_q*.sql; do
  q=$(basename $f .sql); q=${q##*_}; t=""
  for run in 1 2 3 4 5; do
    (echo "EXPLAIN (ANALYZE, BUFFERS)"; cat $f) | psql -d vant_personal -q -P pager=off > plans/$phase/Dele-Adelusi_Oluwanisola_301910982_$q.txt
    t="$t,$(grep 'Execution Time' plans/$phase/Dele-Adelusi_Oluwanisola_301910982_$q.txt | awk '{print $3}')"
  done
  echo "$q$t" >> plans/$phase/Dele-Adelusi_Oluwanisola_301910982_times.csv
done
cat plans/$phase/Dele-Adelusi_Oluwanisola_301910982_times.csv
