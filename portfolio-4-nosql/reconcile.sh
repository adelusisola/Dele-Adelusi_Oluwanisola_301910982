#!/usr/bin/env bash
# Compares MongoDB's activity with the PostgreSQL transactions it was built from (customers 1 to 500).
export PGOPTIONS="-c search_path=vant"
pg() { psql -d vant_personal -Atc "$1"; }
mongo() { docker exec vant-mongo mongosh --quiet vant_nosql --eval "$1"; }
EV="select 1 as n, amount, 'IN' as d from transaction where to_account_id <= 500 and status = 'COMPLETED' union all select 1, amount, 'OUT' from transaction where from_account_id <= 500 and status = 'COMPLETED'"
compare() {
  printf '  documents    MongoDB %-12s PostgreSQL %s\n' "$(mongo 'print(db.activity.countDocuments())')" "$(pg "select count(*) from ($EV) x")"
  for dir in IN OUT; do
    m=$(mongo "print(db.activity.aggregate([{\$match:{direction:'$dir'}},{\$group:{_id:null,s:{\$sum:'\$amount'}}}]).toArray()[0].s.toString())")
    p=$(pg "select sum(amount) from ($EV) x where d = '$dir'")
    printf '  total %-3s     MongoDB %-12s PostgreSQL %-12s %s\n' "$dir" "$m" "$p" "$([ "$m" = "$p" ] && echo MATCH || echo MISMATCH)"
  done
}
echo "--- right after the load"; compare
echo; echo "--- after a deposit of 100 is committed in PostgreSQL that MongoDB has not received yet"
id=$(pg "with t as (insert into transaction (type, to_account_id, amount, currency) values ('DEPOSIT', 42, 100, 'NGN') returning txn_id), u as (update account set balance = balance + 100 where account_id = 42) select txn_id from t")
compare
pg "with d as (delete from transaction where txn_id = $id), u as (update account set balance = balance - 100 where account_id = 42) select 1" > /dev/null
echo "  (the test deposit was removed again)"
