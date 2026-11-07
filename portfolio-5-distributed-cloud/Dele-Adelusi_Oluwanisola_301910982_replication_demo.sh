#!/usr/bin/env bash
# Replication, an asynchronous (stale) read, and a failover. The failover stops the primary, so run it last.
p() { docker exec -i vant-primary psql -U vant -d vant_personal -X -q -P pager=off "$@" 2>&1; }
r() { docker exec -i vant-replica psql -U vant -d vant_personal -X -q -P pager=off "$@" 2>&1; }
bal() { "$1" -Atc "select balance from vant.account where account_number='9000000001'"; }

echo "--- 1. Replication status"
p -c "select state, sync_state from pg_stat_replication"
echo "replica is in recovery (read-only): $(r -Atc 'select pg_is_in_recovery()')"

echo; echo "--- 2. A write on the primary appears on the replica"
echo "Adaeze before: primary $(bal p), replica $(bal r)"
p -c "update vant.account set balance = balance + 100 where account_number='9000000001'" > /dev/null
sleep 1
echo "after depositing 100 on the primary: primary $(bal p), replica $(bal r)"

echo; echo "--- 3. The replica refuses writes"
r -c "update vant.account set balance = 0"

echo; echo "--- 4. Replication is asynchronous: a replica that is 3 seconds behind returns old data"
r -c "alter system set recovery_min_apply_delay = '3s'" > /dev/null; r -c "select pg_reload_conf()" > /dev/null; sleep 1
p -c "update vant.account set balance = balance + 100 where account_number='9000000001'" > /dev/null
echo "right after the write:  primary $(bal p), replica $(bal r)   <- stale read"
sleep 4
echo "4 seconds later:        primary $(bal p), replica $(bal r)"
r -c "alter system reset recovery_min_apply_delay" > /dev/null; r -c "select pg_reload_conf()" > /dev/null

echo; echo "--- 5. Failover, and the data it can lose"
NET=$(docker inspect vant-primary --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
docker network disconnect "$NET" vant-replica
echo "the replica loses its network connection to the primary"
for i in 1 2 3; do p -c "update vant.account set balance = balance + 100 where account_number='9000000001'" > /dev/null; done
told=$(bal p)
echo "3 deposits of 100 were acknowledged by the primary, so clients were told Adaeze has $told"
docker stop vant-primary > /dev/null
echo "the primary stops; the replica is promoted"
t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
r -Atc "select 'promoted: ' || pg_promote(wait => true)"
until r -c "update vant.account set balance = balance + 100 where account_number='9000000001'" > /dev/null 2>&1; do sleep 0.2; done
t1=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "the new primary accepted its first write $(perl -e "printf '%.1f', $t1 - $t0") seconds after the promote command"
echo "Adaeze on the new primary: $(bal r)   (after one new deposit of 100; the old primary had $told)"
echo "so the 3 acknowledged deposits (300) are missing: $(perl -e "printf '%.2f', $told + 100 - $(bal r)") lost"
