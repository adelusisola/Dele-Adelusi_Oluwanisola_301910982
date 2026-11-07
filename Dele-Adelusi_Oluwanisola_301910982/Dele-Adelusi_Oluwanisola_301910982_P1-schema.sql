DROP SCHEMA IF EXISTS vant CASCADE;
CREATE SCHEMA vant;
SET search_path TO vant;

CREATE TABLE customer (
    customer_id   SERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(15)  NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years')
);

CREATE TABLE account (
    account_id     SERIAL PRIMARY KEY,
    customer_id    INT NOT NULL REFERENCES customer(customer_id),
    account_number CHAR(10) NOT NULL UNIQUE,
    type           VARCHAR(10) NOT NULL CHECK (type IN ('WALLET', 'SAVINGS')),
    currency       CHAR(3) NOT NULL CHECK (currency IN ('NGN', 'USD')),
    balance        NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    created_at     TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (customer_id, type, currency),
    UNIQUE (account_id, currency)
);

CREATE TABLE savings_goal (
    goal_id       SERIAL PRIMARY KEY,
    account_id    INT NOT NULL REFERENCES account(account_id),
    name          VARCHAR(60) NOT NULL,
    target_amount NUMERIC(14,2) NOT NULL CHECK (target_amount > 0),
    target_date   DATE,
    status        VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED'))
);

CREATE TABLE beneficiary (
    beneficiary_id SERIAL PRIMARY KEY,
    customer_id    INT NOT NULL REFERENCES customer(customer_id),
    bank_name      VARCHAR(60) NOT NULL,
    account_number CHAR(10) NOT NULL,
    account_name   VARCHAR(100) NOT NULL,
    UNIQUE (customer_id, bank_name, account_number)
);

CREATE TABLE transaction (
    txn_id          BIGSERIAL PRIMARY KEY,
    idempotency_key VARCHAR(64) UNIQUE,
    type            VARCHAR(10) NOT NULL CHECK (type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER')),
    from_account_id INT,
    to_account_id   INT,
    beneficiary_id  INT REFERENCES beneficiary(beneficiary_id),
    amount          NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    currency        CHAR(3) NOT NULL CHECK (currency IN ('NGN', 'USD')),
    status          VARCHAR(10) NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED')),
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    -- both accounts must hold the transaction's currency, so NGN cannot move to USD without a conversion
    FOREIGN KEY (from_account_id, currency) REFERENCES account (account_id, currency),
    FOREIGN KEY (to_account_id, currency)   REFERENCES account (account_id, currency),
    CHECK (from_account_id IS DISTINCT FROM to_account_id),
    CHECK (
        (type = 'DEPOSIT'    AND from_account_id IS NULL     AND to_account_id IS NOT NULL AND beneficiary_id IS NULL) OR
        (type = 'WITHDRAWAL' AND from_account_id IS NOT NULL AND to_account_id IS NULL     AND beneficiary_id IS NULL) OR
        (type = 'TRANSFER'   AND from_account_id IS NOT NULL AND (to_account_id IS NULL) <> (beneficiary_id IS NULL))
    ),
    CHECK (beneficiary_id IS NULL OR currency = 'NGN')
);

-- stored balance next to the balance that the completed transactions add up to
CREATE VIEW balance_check AS
SELECT a.account_id, a.account_number, a.balance AS stored_balance,
       COALESCE(SUM(CASE WHEN t.to_account_id = a.account_id THEN t.amount ELSE -t.amount END), 0) AS from_transactions
FROM account a
LEFT JOIN transaction t ON a.account_id IN (t.from_account_id, t.to_account_id) AND t.status = 'COMPLETED'
GROUP BY a.account_id, a.account_number, a.balance;
