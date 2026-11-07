#!/usr/bin/env bash
export PGOPTIONS="-c search_path=vant"
DB=vant_personal
ADAEZE=$(psql -d $DB -Atc "select account_id from vant.account where account_number='9000000001'")
EMEKA=$(psql -d $DB -Atc "select account_id from vant.account where account_number='9000000002'")
q() { psql -d $DB -X -q -P pager=off -v adaeze=$ADAEZE -v emeka=$EMEKA "$@" 2>&1 | grep -v '^CONTEXT'; }
show() { q -c "select account_number, balance, expected_balance from demo_check order by 1"; }
