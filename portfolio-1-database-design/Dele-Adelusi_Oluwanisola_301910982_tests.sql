-- Automated checks. Each one prints PASS or FAIL, and the script ends with an overall verdict.
-- Run it on an empty schema (after Dele-Adelusi_Oluwanisola_301910982_schema.sql). Everything it creates is rolled back at the end, and the id counters are reset to 1.
-- It stops at once if the schema already holds data, so it can never delete real data.
\set ON_ERROR_STOP on
SET search_path TO vant;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM customer) THEN RAISE EXCEPTION 'Dele-Adelusi_Oluwanisola_301910982_tests.sql needs an empty schema: run Dele-Adelusi_Oluwanisola_301910982_schema.sql first'; END IF;
END $$;

TRUNCATE customer, account, savings_goal, beneficiary, transaction RESTART IDENTITY CASCADE;
BEGIN;
CREATE TEMP TABLE results (n serial, test text, outcome text, detail text);

-- a statement that must be accepted
CREATE FUNCTION pg_temp.must_work(p_test text, p_sql text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    INSERT INTO results (test, outcome, detail) VALUES (p_test, 'PASS', 'accepted');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO results (test, outcome, detail) VALUES (p_test, 'FAIL', SQLERRM);
END $$;

-- a statement that must be rejected by a rule (if it is accepted, it is undone and the test fails)
CREATE FUNCTION pg_temp.must_fail(p_test text, p_sql text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE p_sql;
        RAISE EXCEPTION 'accepted' USING ERRCODE = 'XX999';
    EXCEPTION
        WHEN SQLSTATE 'XX999' THEN
            INSERT INTO results (test, outcome, detail) VALUES (p_test, 'FAIL', 'accepted, but it should have been rejected');
        WHEN OTHERS THEN
            INSERT INTO results (test, outcome, detail) VALUES (p_test, 'PASS', SQLERRM);
    END;
END $$;

-- a query that must return true
CREATE FUNCTION pg_temp.must_be_true(p_test text, p_sql text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v boolean;
BEGIN
    EXECUTE p_sql INTO v;
    INSERT INTO results (test, outcome, detail) VALUES (p_test, CASE WHEN v THEN 'PASS' ELSE 'FAIL' END, 'returned ' || v);
END $$;

INSERT INTO customer (full_name, email, phone, date_of_birth) VALUES ('Ada Okafor', 'ada@example.com', '08011111111', '1996-04-12');
INSERT INTO account (customer_id, account_number, type, currency) VALUES (1, '1000000001', 'WALLET', 'NGN');
INSERT INTO account (customer_id, account_number, type, currency) VALUES (1, '1000000002', 'SAVINGS', 'NGN');
INSERT INTO account (customer_id, account_number, type, currency) VALUES (1, '1000000003', 'WALLET', 'USD');
INSERT INTO beneficiary (customer_id, bank_name, account_number, account_name) VALUES (1, 'GTBank', '0123456789', 'Ada Okafor');

\o /dev/null
-- rules that must accept valid data and keep the stored balance honest
SELECT pg_temp.must_work('a deposit and its balance update in one statement is accepted',
    $$WITH t AS (INSERT INTO transaction (type, to_account_id, amount, currency) VALUES ('DEPOSIT', 1, 1000, 'NGN'))
      UPDATE account SET balance = balance + 1000 WHERE account_id = 1$$);
SELECT pg_temp.must_be_true('the stored balance equals the completed transactions',
    $$SELECT count(*) = 0 FROM balance_check WHERE stored_balance <> from_transactions$$);
DO $$
DECLARE n int;
BEGIN
    BEGIN
        UPDATE account SET balance = balance + 500 WHERE account_id = 1;
        SELECT count(*) INTO n FROM balance_check WHERE stored_balance <> from_transactions;
        RAISE EXCEPTION 'undo' USING ERRCODE = 'XX999';
    EXCEPTION WHEN SQLSTATE 'XX999' THEN
        INSERT INTO results (test, outcome, detail) VALUES ('a balance changed without a transaction row is detected', CASE WHEN n = 1 THEN 'PASS' ELSE 'FAIL' END, n || ' account flagged');
    END;
END $$;
SELECT pg_temp.must_work('the first use of an idempotency key is accepted',
    $$INSERT INTO transaction (idempotency_key, type, to_account_id, amount, currency) VALUES ('key-1', 'DEPOSIT', 2, 10, 'NGN')$$);

-- rules that must reject bad data
SELECT pg_temp.must_fail('duplicate email', $$INSERT INTO customer (full_name, email, phone, date_of_birth) VALUES ('Dup', 'ada@example.com', '08022222222', '1990-01-01')$$);
SELECT pg_temp.must_fail('customer under 18', $$INSERT INTO customer (full_name, email, phone, date_of_birth) VALUES ('Kid', 'kid@example.com', '08033333333', CURRENT_DATE - INTERVAL '10 years')$$);
SELECT pg_temp.must_fail('negative balance', $$UPDATE account SET balance = -1 WHERE account_id = 1$$);
SELECT pg_temp.must_fail('second NGN wallet for the same customer', $$INSERT INTO account (customer_id, account_number, type, currency) VALUES (1, '1000000004', 'WALLET', 'NGN')$$);
SELECT pg_temp.must_fail('withdrawal that names a destination account', $$INSERT INTO transaction (type, from_account_id, to_account_id, amount, currency) VALUES ('WITHDRAWAL', 1, 2, 100, 'NGN')$$);
SELECT pg_temp.must_fail('transfer to the same account', $$INSERT INTO transaction (type, from_account_id, to_account_id, amount, currency) VALUES ('TRANSFER', 1, 1, 100, 'NGN')$$);
SELECT pg_temp.must_fail('transfer with both a destination account and a beneficiary', $$INSERT INTO transaction (type, from_account_id, to_account_id, beneficiary_id, amount, currency) VALUES ('TRANSFER', 1, 2, 1, 100, 'NGN')$$);
SELECT pg_temp.must_fail('transfer from an NGN account to a USD account', $$INSERT INTO transaction (type, from_account_id, to_account_id, amount, currency) VALUES ('TRANSFER', 1, 3, 100, 'NGN')$$);
SELECT pg_temp.must_fail('deposit that names a beneficiary', $$INSERT INTO transaction (type, to_account_id, beneficiary_id, amount, currency) VALUES ('DEPOSIT', 1, 1, 100, 'NGN')$$);
SELECT pg_temp.must_fail('zero amount', $$INSERT INTO transaction (type, to_account_id, amount, currency) VALUES ('DEPOSIT', 1, 0, 'NGN')$$);
SELECT pg_temp.must_fail('the same idempotency key used twice', $$INSERT INTO transaction (idempotency_key, type, to_account_id, amount, currency) VALUES ('key-1', 'DEPOSIT', 2, 10, 'NGN')$$);
SELECT pg_temp.must_fail('account for a customer that does not exist', $$INSERT INTO account (customer_id, account_number, type, currency) VALUES (99, '1000000009', 'WALLET', 'USD')$$);

\o
\pset footer off
SELECT n, outcome, test, left(detail, 62) AS detail FROM results ORDER BY n;
SELECT count(*) FILTER (WHERE outcome = 'PASS') AS passed, count(*) FILTER (WHERE outcome = 'FAIL') AS failed,
       CASE WHEN count(*) FILTER (WHERE outcome = 'FAIL') = 0 THEN 'ALL TESTS PASSED' ELSE 'SOME TESTS FAILED' END AS verdict
FROM results;
ROLLBACK;
-- the rolled-back inserts used up id numbers; reset them so the next script starts from 1 (the schema is empty here)
TRUNCATE customer, account, savings_goal, beneficiary, transaction RESTART IDENTITY CASCADE;
