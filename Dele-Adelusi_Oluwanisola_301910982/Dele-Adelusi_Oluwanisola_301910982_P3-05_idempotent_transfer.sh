#!/usr/bin/env bash
# The production-style transfer: the same request (same key) must move money once, however it is repeated,
# and a key reused for a different request must be rejected.
source "$(dirname "$0")/lib.sh"
q -c "select reset_demo()" > /dev/null
echo "--- a client retries: the same request, key pay-123, sent twice one after the other"
q -At -c "select '  first call:  ' || transfer_idempotent('pay-123', $ADAEZE, $EMEKA, 100)"
q -At -c "select '  second call: ' || transfer_idempotent('pay-123', $ADAEZE, $EMEKA, 100)"
echo "--- the key pay-123 reused for a different transfer (500 instead of 100)"
q -At -c "select '  third call:  ' || transfer_idempotent('pay-123', $ADAEZE, $EMEKA, 500)"
echo "--- balances after all three calls: only the first one moved money"
show
echo
q -c "select reset_demo()" > /dev/null
echo "--- a double tap: the same request, key pay-456, sent twice at the same moment"
q -At -c "select '  call A: ' || transfer_idempotent('pay-456', $ADAEZE, $EMEKA, 100, 2)" &
( sleep 0.3; q -At -c "select '  call B: ' || transfer_idempotent('pay-456', $ADAEZE, $EMEKA, 100)" ) &
wait
show
