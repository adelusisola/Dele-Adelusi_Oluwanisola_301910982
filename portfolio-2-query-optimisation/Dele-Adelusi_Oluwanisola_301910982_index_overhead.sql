-- What the three indexes cost: disk space, and insert time (each insert is rolled back, so the data is unchanged)
SET search_path TO vant;
-- start from freshly built indexes so the sizes are not inflated by earlier rolled-back inserts
REINDEX TABLE transaction;
SELECT 'transaction table' AS object, pg_size_pretty(pg_table_size('transaction')) AS size
UNION ALL SELECT indexrelname::text, pg_size_pretty(pg_relation_size(indexrelid)) FROM pg_stat_user_indexes WHERE relname = 'transaction' AND indexrelname LIKE 'ix_%';
\timing off
\echo '--- insert 100,000 rows WITH the three indexes, then WITHOUT them (each run is rolled back), twice'
\echo 'with indexes:'
BEGIN;
\timing on
INSERT INTO transaction (type, to_account_id, amount, currency) SELECT 'DEPOSIT', 1 + i % 5000, 100, 'NGN' FROM generate_series(1, 100000) i;
\timing off
ROLLBACK;
\echo 'without indexes:'
BEGIN;
DROP INDEX ix_txn_from, ix_txn_to, ix_txn_pending;
\timing on
INSERT INTO transaction (type, to_account_id, amount, currency) SELECT 'DEPOSIT', 1 + i % 5000, 100, 'NGN' FROM generate_series(1, 100000) i;
\timing off
ROLLBACK;
\echo 'with indexes:'
BEGIN;
\timing on
INSERT INTO transaction (type, to_account_id, amount, currency) SELECT 'DEPOSIT', 1 + i % 5000, 100, 'NGN' FROM generate_series(1, 100000) i;
\timing off
ROLLBACK;
\echo 'without indexes:'
BEGIN;
DROP INDEX ix_txn_from, ix_txn_to, ix_txn_pending;
\timing on
INSERT INTO transaction (type, to_account_id, amount, currency) SELECT 'DEPOSIT', 1 + i % 5000, 100, 'NGN' FROM generate_series(1, 100000) i;
\timing off
ROLLBACK;
