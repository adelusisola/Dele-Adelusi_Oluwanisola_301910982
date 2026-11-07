-- Q1 account statement: the 10 latest transactions of account 123
SELECT txn_id, type, from_account_id, to_account_id, amount, status, created_at
FROM transaction
WHERE from_account_id = 123 OR to_account_id = 123
ORDER BY created_at DESC
LIMIT 10;
