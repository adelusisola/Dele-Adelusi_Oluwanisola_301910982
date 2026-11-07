SET search_path TO vant;
SELECT reset_demo() \gset
\echo
\echo '--- 1. COMMIT: transfer 100 from Adaeze to Emeka'
BEGIN;
SELECT transfer(:adaeze, :emeka, 100) \gset
SELECT account_number, balance FROM account WHERE account_id IN (:adaeze, :emeka) ORDER BY 1;
COMMIT;
\echo 'after COMMIT the change is permanent:'
SELECT account_number, balance FROM account WHERE account_id IN (:adaeze, :emeka) ORDER BY 1;
\echo
\echo '--- 2. ROLLBACK: transfer 300, then change our mind'
BEGIN;
SELECT transfer(:adaeze, :emeka, 300) \gset
SELECT account_number, balance FROM account WHERE account_id IN (:adaeze, :emeka) ORDER BY 1;
ROLLBACK;
\echo 'after ROLLBACK the balances are back and no transaction row was kept:'
SELECT account_number, balance FROM account WHERE account_id IN (:adaeze, :emeka) ORDER BY 1;
SELECT count(*) AS transactions_kept FROM transaction WHERE amount = 300 AND from_account_id = :adaeze;
\echo
\echo '--- 3. ROLLBACK on error: transfer 5000 from an account holding 900'
\set ON_ERROR_STOP off
SELECT transfer(:adaeze, :emeka, 5000) \gset
\set ON_ERROR_STOP on
\echo 'the failed transfer changed nothing:'
SELECT account_number, balance FROM account WHERE account_id IN (:adaeze, :emeka) ORDER BY 1;
