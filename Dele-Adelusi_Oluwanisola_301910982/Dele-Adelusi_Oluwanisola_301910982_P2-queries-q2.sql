-- Q2 monthly totals by transaction type
SELECT date_trunc('month', created_at) AS month, type, count(*) AS txns, sum(amount) AS total
FROM transaction
WHERE status = 'COMPLETED'
GROUP BY 1, 2
ORDER BY 1, 2;
