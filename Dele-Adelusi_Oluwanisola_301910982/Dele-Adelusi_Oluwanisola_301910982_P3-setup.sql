SET search_path TO vant;

INSERT INTO customer (full_name, email, phone, date_of_birth) VALUES
    ('Demo Adaeze', 'adaeze@demo.example.com', '09000000001', '1990-01-01'),
    ('Demo Emeka',   'emeka@demo.example.com',   '09000000002', '1991-02-02')
ON CONFLICT DO NOTHING;
INSERT INTO account (customer_id, account_number, type, currency)
SELECT customer_id, CASE full_name WHEN 'Demo Adaeze' THEN '9000000001' ELSE '9000000002' END, 'WALLET', 'NGN'
FROM customer WHERE full_name IN ('Demo Adaeze', 'Demo Emeka')
ON CONFLICT DO NOTHING;

-- puts both demo accounts back to 1000 NGN, with a funding deposit so each balance matches its transactions
CREATE OR REPLACE FUNCTION reset_demo() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM transaction WHERE from_account_id IN (SELECT account_id FROM account WHERE account_number IN ('9000000001', '9000000002'))
                               OR to_account_id IN (SELECT account_id FROM account WHERE account_number IN ('9000000001', '9000000002'));
    UPDATE account SET balance = 1000 WHERE account_number IN ('9000000001', '9000000002');
    INSERT INTO transaction (type, to_account_id, amount, currency)
    SELECT 'DEPOSIT', account_id, 1000, 'NGN' FROM account WHERE account_number IN ('9000000001', '9000000002');
END $$;

-- stored balance next to the balance the transactions add up to (the balance_check view from Portfolio 1)
CREATE OR REPLACE VIEW demo_check AS
SELECT account_number, stored_balance AS balance, from_transactions AS expected_balance
FROM balance_check WHERE account_number IN ('9000000001', '9000000002');

-- plain transfer: if the debit would make the balance negative, the CHECK fails and everything is undone
CREATE OR REPLACE FUNCTION transfer(p_from int, p_to int, p_amount numeric) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE account SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE account SET balance = balance + p_amount WHERE account_id = p_to;
    INSERT INTO transaction (type, from_account_id, to_account_id, amount, currency)
    SELECT 'TRANSFER', p_from, p_to, p_amount, currency FROM account WHERE account_id = p_from;
END $$;

-- WRONG: reads the balance, waits, then writes back the value it read (lost update)
CREATE OR REPLACE FUNCTION withdraw_unsafe(p_acct int, p_amount numeric, p_pause numeric) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE v numeric;
BEGIN
    SELECT balance INTO v FROM account WHERE account_id = p_acct;
    IF v < p_amount THEN RAISE EXCEPTION 'insufficient funds'; END IF;
    PERFORM pg_sleep(p_pause);
    UPDATE account SET balance = v - p_amount WHERE account_id = p_acct;
    INSERT INTO transaction (type, from_account_id, amount, currency)
    SELECT 'WITHDRAWAL', p_acct, p_amount, currency FROM account WHERE account_id = p_acct;
    RETURN v - p_amount;
END $$;

-- FIX: FOR UPDATE locks the row, so the second withdrawal waits and then sees the new balance
CREATE OR REPLACE FUNCTION withdraw_safe(p_acct int, p_amount numeric, p_pause numeric) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE v numeric;
BEGIN
    SELECT balance INTO v FROM account WHERE account_id = p_acct FOR UPDATE;
    IF v < p_amount THEN RAISE EXCEPTION 'insufficient funds'; END IF;
    PERFORM pg_sleep(p_pause);
    UPDATE account SET balance = balance - p_amount WHERE account_id = p_acct;
    INSERT INTO transaction (type, from_account_id, amount, currency)
    SELECT 'WITHDRAWAL', p_acct, p_amount, currency FROM account WHERE account_id = p_acct;
    RETURN v - p_amount;
END $$;

-- WRONG: locks the source first, then the destination, so opposite transfers can deadlock
CREATE OR REPLACE FUNCTION transfer_slow(p_from int, p_to int, p_amount numeric) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    UPDATE account SET balance = balance - p_amount WHERE account_id = p_from;
    PERFORM pg_sleep(1);
    UPDATE account SET balance = balance + p_amount WHERE account_id = p_to;
    INSERT INTO transaction (type, from_account_id, to_account_id, amount, currency)
    SELECT 'TRANSFER', p_from, p_to, p_amount, currency FROM account WHERE account_id = p_from;
END $$;

-- FIX: always lock the two accounts in account_id order
CREATE OR REPLACE FUNCTION transfer_ordered(p_from int, p_to int, p_amount numeric) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM 1 FROM account WHERE account_id IN (p_from, p_to) ORDER BY account_id FOR UPDATE;
    PERFORM pg_sleep(1);
    UPDATE account SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE account SET balance = balance + p_amount WHERE account_id = p_to;
    INSERT INTO transaction (type, from_account_id, to_account_id, amount, currency)
    SELECT 'TRANSFER', p_from, p_to, p_amount, currency FROM account WHERE account_id = p_from;
END $$;

-- PRODUCTION PATTERN: accounts are locked in id order first. The same key with the same details changes nothing;
-- the same key with different details is rejected, because it is a different request that has reused the key
CREATE OR REPLACE FUNCTION transfer_idempotent(p_key text, p_from int, p_to int, p_amount numeric, p_pause numeric DEFAULT 0) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
    v_txn bigint;
    v_old transaction%ROWTYPE;
BEGIN
    PERFORM 1 FROM account WHERE account_id IN (p_from, p_to) ORDER BY account_id FOR UPDATE;
    PERFORM pg_sleep(p_pause);
    INSERT INTO transaction (idempotency_key, type, from_account_id, to_account_id, amount, currency)
    SELECT p_key, 'TRANSFER', p_from, p_to, p_amount, currency FROM account WHERE account_id = p_from
    ON CONFLICT (idempotency_key) DO NOTHING RETURNING txn_id INTO v_txn;
    IF v_txn IS NULL THEN
        SELECT * INTO v_old FROM transaction WHERE idempotency_key = p_key;
        IF v_old.type <> 'TRANSFER' OR v_old.from_account_id IS DISTINCT FROM p_from
           OR v_old.to_account_id IS DISTINCT FROM p_to OR v_old.amount <> p_amount THEN
            RAISE EXCEPTION 'idempotency key % was already used for a different request', p_key;
        END IF;
        RETURN 'duplicate request, nothing changed';
    END IF;
    UPDATE account SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE account SET balance = balance + p_amount WHERE account_id = p_to;
    RETURN 'transfer done';
END $$;
