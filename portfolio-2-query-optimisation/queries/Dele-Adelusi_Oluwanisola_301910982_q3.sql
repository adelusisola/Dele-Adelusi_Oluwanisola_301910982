-- Q3 top 10 customers by total withdrawn (two joins and a group)
SELECT c.customer_id, c.full_name, sum(t.amount) AS withdrawn
FROM transaction t
JOIN account a ON a.account_id = t.from_account_id
JOIN customer c ON c.customer_id = a.customer_id
WHERE t.type = 'WITHDRAWAL' AND t.status = 'COMPLETED'
GROUP BY c.customer_id, c.full_name
ORDER BY withdrawn DESC
LIMIT 10;
