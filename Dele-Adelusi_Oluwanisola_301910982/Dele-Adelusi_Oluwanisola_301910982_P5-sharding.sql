-- Hash partitioning of the transactions on one server: the single-server form of sharding.
-- In a real sharded system each partition would live on a different server.
SET search_path TO vant;
DROP TABLE IF EXISTS txn_sharded;
CREATE TABLE txn_sharded (
    txn_id          BIGINT,
    from_account_id INT NOT NULL,
    amount          NUMERIC(14,2),
    created_at      TIMESTAMP
) PARTITION BY HASH (from_account_id);
CREATE TABLE txn_shard_0 PARTITION OF txn_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE txn_shard_1 PARTITION OF txn_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE txn_shard_2 PARTITION OF txn_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE txn_shard_3 PARTITION OF txn_sharded FOR VALUES WITH (MODULUS 4, REMAINDER 3);
INSERT INTO txn_sharded SELECT txn_id, from_account_id, amount, created_at FROM transaction WHERE from_account_id IS NOT NULL;
ANALYZE txn_sharded;

\echo '--- rows per shard (the hash of from_account_id decides the shard)'
SELECT tableoid::regclass AS shard, count(*) AS transactions, count(DISTINCT from_account_id) AS accounts FROM txn_sharded GROUP BY 1 ORDER BY 1;

\echo '--- a query that names the shard key reads ONE shard'
EXPLAIN (COSTS OFF) SELECT * FROM txn_sharded WHERE from_account_id = 123;

\echo '--- a query without the shard key reads ALL shards'
EXPLAIN (COSTS OFF) SELECT count(*) FROM txn_sharded WHERE amount > 40000;
