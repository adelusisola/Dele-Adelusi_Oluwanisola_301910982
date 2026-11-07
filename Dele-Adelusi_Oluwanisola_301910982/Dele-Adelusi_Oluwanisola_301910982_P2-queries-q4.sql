-- Q4 savings goal progress
SELECT g.name, g.target_amount, a.balance, round(100 * a.balance / g.target_amount, 1) AS percent_saved
FROM savings_goal g
JOIN account a ON a.account_id = g.account_id
WHERE g.status = 'ACTIVE'
ORDER BY percent_saved DESC
LIMIT 10;
