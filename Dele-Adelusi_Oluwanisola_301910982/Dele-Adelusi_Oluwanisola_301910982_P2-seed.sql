SET search_path TO vant;
-- fixed reference date, so every run builds identical data and the saved results can be reproduced exactly
\set anchor '2026-11-07 12:00:00'

INSERT INTO customer (full_name, email, phone, date_of_birth)
SELECT (ARRAY['Adaeze','Chinedu','Emeka','Ngozi','Tunde','Funke','Ibrahim','Aisha','Obinna','Chiamaka','Segun','Bukola','Musa','Zainab','Kelechi','Yetunde','Uche','Amina','Femi','Ifeoma'])[1 + n % 20] || ' ' || (ARRAY['Okafor','Adeyemi','Balogun','Eze','Bello','Okonkwo','Abubakar','Ogunleye','Nwosu','Ibrahim','Adebayo','Chukwu','Lawal','Obi','Yusuf','Afolabi','Nnamdi','Olawale','Danjuma','Oladipo'])[1 + (n / 20) % 20], 'user' || n || '@example.com', '080' || lpad(n::text, 8, '0'), DATE '1960-01-01' + (n * 7 % 16000)
FROM generate_series(1, 5000) n;

-- wallets get account_id 1 to 5000 (same as customer_id), savings accounts follow
INSERT INTO account (customer_id, account_number, type, currency, balance)
SELECT n, '1' || lpad(n::text, 9, '0'), 'WALLET', 'NGN', 50000 + n * 37 % 100000 FROM generate_series(1, 5000) n;
INSERT INTO account (customer_id, account_number, type, currency, balance)
SELECT n, '2' || lpad(n::text, 9, '0'), 'SAVINGS', 'NGN', n * 13 % 50000 FROM generate_series(1, 5000) n WHERE n % 5 < 2;

INSERT INTO savings_goal (account_id, name, target_amount, target_date)
SELECT account_id, (ARRAY['Rent', 'Emergency fund', 'New phone', 'Travel', 'School fees'])[1 + account_id % 5],
       20000 + account_id * 17 % 80000, CURRENT_DATE + (account_id % 400)
FROM account WHERE type = 'SAVINGS';

INSERT INTO beneficiary (customer_id, bank_name, account_number, account_name)
SELECT n, (ARRAY['GTBank', 'Access Bank', 'Zenith Bank', 'UBA'])[1 + n % 4], lpad((n * 7919 % 1000000000)::text, 10, '0'), (ARRAY['Adaeze','Chinedu','Emeka','Ngozi','Tunde','Funke','Ibrahim','Aisha','Obinna','Chiamaka','Segun','Bukola','Musa','Zainab','Kelechi','Yetunde','Uche','Amina','Femi','Ifeoma'])[1 + (n + 7) % 20] || ' ' || (ARRAY['Okafor','Adeyemi','Balogun','Eze','Bello','Okonkwo','Abubakar','Ogunleye','Nwosu','Ibrahim','Adebayo','Chukwu','Lawal','Obi','Yusuf','Afolabi','Nnamdi','Olawale','Danjuma','Oladipo'])[1 + (n / 20 + 3) % 20]
FROM generate_series(1, 5000) n;

-- every wallet starts with an opening deposit, so balances can be derived from the transactions and never go negative
INSERT INTO transaction (type, to_account_id, amount, currency, created_at)
SELECT 'DEPOSIT', account_id, 5000000, 'NGN', :'anchor'::timestamp - interval '400 days' FROM account WHERE type = 'WALLET';

-- 200,000 transactions: 30% deposits, 30% withdrawals, 30% transfers between accounts, 10% transfers to a beneficiary
INSERT INTO transaction (type, from_account_id, to_account_id, beneficiary_id, amount, currency, status, created_at)
SELECT CASE WHEN k < 30 THEN 'DEPOSIT' WHEN k < 60 THEN 'WITHDRAWAL' ELSE 'TRANSFER' END,
       CASE WHEN k >= 30 THEN a END,
       CASE WHEN k < 30 THEN a WHEN k >= 60 AND k < 90 THEN 1 + (a + h2 % 6999) % 7000 END,
       CASE WHEN k >= 90 THEN a END,
       100 + h4 % 50000,
       'NGN',
       CASE WHEN h5 % 100 < 95 THEN 'COMPLETED' WHEN h5 % 100 < 99 THEN 'FAILED' ELSE 'PENDING' END,
       :'anchor'::timestamp - (h6 % 365) * interval '1 day' - (h6 % 86400) * interval '1 second'
FROM (SELECT 1 + (hashtext(i || 'a')::bigint & 2147483647) % 5000 AS a,
             (hashtext(i || 'b')::bigint & 2147483647) AS h2,
             (hashtext(i || 'c')::bigint & 2147483647) % 100 AS k,
             (hashtext(i || 'd')::bigint & 2147483647) AS h4,
             (hashtext(i || 'e')::bigint & 2147483647) AS h5,
             (hashtext(i || 'f')::bigint & 2147483647) AS h6
      FROM generate_series(1, 200000) i) x;

-- the stored balance is the sum of the completed transactions (the rule that invariants.sql checks)
UPDATE account a SET balance = b.from_transactions FROM balance_check b WHERE b.account_id = a.account_id;

ANALYZE;
SELECT 'customers' AS "table", count(*) FROM customer UNION ALL SELECT 'accounts', count(*) FROM account
UNION ALL SELECT 'savings goals', count(*) FROM savings_goal UNION ALL SELECT 'transactions', count(*) FROM transaction;
