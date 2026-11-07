#!/usr/bin/env bash
# Two withdrawals of 800 from an account holding 1000 at the same time. Only one should succeed.
source "$(dirname "$0")/Dele-Adelusi_Oluwanisola_301910982_lib.sh"
run() {
  q -At -c "select 'session A: new balance ' || $1($ADAEZE, 800, 2)" | sed 's/^/  /' &
  ( sleep 0.3; q -At -c "select 'session B: new balance ' || $1($ADAEZE, 800, 1)" | sed 's/^/  /' ) &
  wait
  show
}
q -c "select reset_demo()" > /dev/null
echo "--- WRONG: withdraw_unsafe reads the balance, waits, then writes the value it read"
run withdraw_unsafe
echo
q -c "select reset_demo()" > /dev/null
echo "--- FIX: withdraw_safe locks the row first (SELECT ... FOR UPDATE)"
run withdraw_safe
