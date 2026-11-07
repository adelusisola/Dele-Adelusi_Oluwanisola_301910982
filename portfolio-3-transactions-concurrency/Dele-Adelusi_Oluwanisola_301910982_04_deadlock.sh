#!/usr/bin/env bash
# Adaeze pays Emeka while Emeka pays Adaeze.
source "$(dirname "$0")/Dele-Adelusi_Oluwanisola_301910982_lib.sh"
run() {
  q -At -c "select $1($ADAEZE, $EMEKA, 100); select 'A: Adaeze to Emeka done'" | grep -v '^$' | sed 's/^/  /' &
  ( sleep 0.2; q -At -c "select $1($EMEKA, $ADAEZE, 50); select 'B: Emeka to Adaeze done'" | grep -v '^$' | sed 's/^/  /' ) &
  wait
  show
}
q -c "select reset_demo()" > /dev/null
echo "--- WRONG: transfer_slow locks the source account, then the destination"
run transfer_slow
echo
q -c "select reset_demo()" > /dev/null
echo "--- FIX: transfer_ordered locks both accounts in account_id order"
run transfer_ordered
