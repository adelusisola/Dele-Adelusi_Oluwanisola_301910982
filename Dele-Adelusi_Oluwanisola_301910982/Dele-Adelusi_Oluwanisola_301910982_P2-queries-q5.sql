-- Q5 oldest pending transactions
SELECT txn_id, type, amount, created_at
FROM transaction
WHERE status = 'PENDING'
ORDER BY created_at
LIMIT 20;
