-- Turns the completed PostgreSQL transactions of customers 1 to 500 into MongoDB activity documents (one JSON line each).
-- In the Portfolio 2 data, a customer's wallet has the same id as the customer, so wallet ids 1 to 500 are customers 1 to 500.
\set QUIET on
\t on
\pset format unaligned
SET search_path TO vant;
\o data/activity.jsonl
SELECT (jsonb_build_object(
    'customerId', e.customer_id,
    'pgTxnId', e.txn_id,
    'type', e.type,
    'direction', e.direction,
    'amount', jsonb_build_object('$numberDecimal', e.amount::text),
    'createdAt', jsonb_build_object('$date', to_char(e.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')))
  || CASE
       WHEN e.type = 'DEPOSIT' THEN jsonb_build_object('source', (ARRAY['BANK_TRANSFER', 'CARD', 'CASH_AGENT'])[1 + e.txn_id % 3])
       WHEN e.type = 'WITHDRAWAL' THEN jsonb_build_object('channel', (ARRAY['ATM', 'USSD', 'APP'])[1 + e.txn_id % 3])
       WHEN e.direction = 'OUT' THEN jsonb_build_object('category', (ARRAY['Groceries', 'Transport', 'Bills', 'Eating out', 'Shopping'])[1 + e.txn_id % 5],
                                                         'toName', CASE WHEN e.beneficiary_id IS NOT NULL THEN 'Beneficiary ' || e.beneficiary_id ELSE 'Account ' || e.to_account_id END)
       ELSE jsonb_build_object('fromAccount', e.from_account_id)
     END)::text
FROM (
    SELECT from_account_id AS customer_id, txn_id, type, 'OUT' AS direction, amount, created_at, from_account_id, to_account_id, beneficiary_id
    FROM transaction WHERE from_account_id <= 500 AND status = 'COMPLETED'
    UNION ALL
    SELECT to_account_id, txn_id, type, 'IN', amount, created_at, from_account_id, to_account_id, beneficiary_id
    FROM transaction WHERE to_account_id <= 500 AND status = 'COMPLETED'
) e;
\o
