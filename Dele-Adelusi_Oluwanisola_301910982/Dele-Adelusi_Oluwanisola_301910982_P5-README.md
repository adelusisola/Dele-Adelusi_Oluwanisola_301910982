# Portfolio 5: Distributed and Cloud Database Exercise

I built a replicated PostgreSQL pair in Docker and a hash-partitioned table, and wrote a short discussion and a cloud design. I did not deploy to a cloud provider.

## 1. Replication, consistency and availability

[replication_demo.sh](replication_demo.sh) runs a PostgreSQL primary and one streaming replica in Docker, with the Portfolio 1 schema and a demo account.

- **Replication works.** A deposit of 100 on the primary shows up on the replica, and the replica refuses writes (`cannot execute UPDATE in a read-only transaction`).
- **Replication is asynchronous.** I set the replica to apply changes 3 seconds late. A read right after a write returned the old balance (1,100) while the primary showed 1,200. Four seconds later the replica caught up.
- **Failover can lose data.** I cut the replica's network connection and made 3 deposits of 100 on the primary, all acknowledged to the client. Then I stopped the primary and promoted the replica. The new primary accepted writes 0.3 seconds after the promote command, but it did not have the 3 deposits. 300 was lost, even though clients had been told the deposits succeeded.

## 2. Sharding

[sharding.sql](sharding.sql) splits the transactions into four partitions by a hash of `from_account_id`. The rows spread evenly, from 34,110 to 35,657 per partition. A query that names the account reads one partition, and a query that does not reads all four. This is partitioning on one server, the single-server form of sharding. In a real sharded system each partition would be on a different server.

## 3. Discussion

With asynchronous replication a write is acknowledged before the replica has it. That keeps the system fast and available, but a replica read can be stale, and if the primary dies at the wrong moment the last writes can be lost. Synchronous replication waits for the replica, which is safer but slower, and blocks writes if the replica is unreachable.

For Vant, balances and transfers would use the primary, with synchronous replication in a real deployment. The activity feed and notifications can be eventually consistent, so they can be read from replicas or from MongoDB. Sharding by account makes single-account queries cheap, but a transfer between accounts on different shards needs a transaction across two servers, which is harder.

### Failover risks

- **Data loss (RPO).** The recovery point objective is how much recent data the business can afford to lose. For balances it should be zero. The demo lost 3 acknowledged deposits (300). Synchronous replication brings it close to zero, at the cost of slower commits.
- **Recovery time (RTO).** The demo measured only the promotion, 0.3 seconds. A real RTO also includes the time to notice the primary has failed, often tens of seconds, and the time for clients to reconnect. I did not measure detection time.
- **Reconnection.** Applications need an address that follows the primary, such as a DNS name, a proxy or a driver given several hosts. A transaction in flight when the primary failed has an unknown outcome, so the retry must use the idempotency key from Portfolio 3 or the customer could be charged twice.
- **The old primary.** If it comes back it holds writes the new primary never saw. It must be fenced off and rebuilt before it rejoins.
- **Synchronous replication is not a guarantee.** By default a synchronous commit waits for the replica to receive the change, not apply it, so a replica read can still be old. If the synchronous replica fails, the system must either block writes or fall back to asynchronous. Reads from a replica, a cache or the MongoDB copy also lag. So balances shown to customers should be read from the primary, and `invariants.sql` should still run regularly.

## 4. Cloud deployment design (not deployed)

PostgreSQL would run on a managed service such as Amazon RDS, with a standby in a second availability zone and a read replica for reporting. MongoDB would be a managed three-node replica set, for example MongoDB Atlas, across three zones. Both databases would sit in a private network with passwords in a secrets manager, encryption at rest and in transit, and automated backups, because replication would copy a bad delete.

## How to run

```bash
docker compose --profile replication up -d pg-primary pg-replica
./replication_demo.sh
psql -d vant_personal -f sharding.sql
docker compose --profile replication down -v
```

Run the compose commands from the repository root. The demo stops the primary at the end, and sharding.sql runs on the local database after Portfolio 2.

Screenshots: [replication, stale read and failover](screenshots/replication.png), [sharding](screenshots/sharding.png).
