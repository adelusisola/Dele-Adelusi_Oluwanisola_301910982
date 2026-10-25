SET search_path TO vant;
CREATE INDEX ix_txn_from ON transaction (from_account_id, created_at);
CREATE INDEX ix_txn_to ON transaction (to_account_id, created_at);
CREATE INDEX ix_txn_pending ON transaction (created_at) WHERE status = 'PENDING';
ANALYZE;
