-- Rules the data must always satisfy. Every count should be 0. Run it after loading data or after any test.
SET search_path TO vant;
SELECT 'stored balance equals the completed transactions' AS rule, count(*) AS violations FROM balance_check WHERE stored_balance <> from_transactions
UNION ALL SELECT 'no negative balance', count(*) FROM account WHERE balance < 0
UNION ALL SELECT 'a transfer keeps one currency', count(*) FROM transaction t JOIN account a ON a.account_id = t.to_account_id WHERE a.currency <> t.currency
UNION ALL SELECT 'a transfer has one destination, not two or none', count(*) FROM transaction WHERE type = 'TRANSFER' AND (to_account_id IS NULL) = (beneficiary_id IS NULL);
