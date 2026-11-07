# Portfolio 4: NoSQL and Advanced Data Models

I used MongoDB, a document database, for the parts of Vant Personal whose fields differ from record to record. Money stays in PostgreSQL.

## Model

There are two collections.

- **activity** has one document per deposit, withdrawal or transfer in a customer's feed (23,553 documents for customers 1 to 500). [Dele-Adelusi_Oluwanisola_301910982_export_activity.sql](Dele-Adelusi_Oluwanisola_301910982_export_activity.sql) builds it from the real PostgreSQL transactions. A document fits because the extra fields differ by type: a deposit has a source, a withdrawal a channel, an outgoing transfer a category and a recipient name, and an incoming transfer a sender account.
- **kyc** has one document per customer's identity checks (500 documents). [Dele-Adelusi_Oluwanisola_301910982_load.js](Dele-Adelusi_Oluwanisola_301910982_load.js) generates them, because PostgreSQL has no KYC table. Its `documents` array holds different shapes, such as a BVN, NIN or passport, a selfie with a liveness score, or a proof of address.

Every activity document keeps `pgTxnId`, the id of its PostgreSQL transaction, and the same `customerId`. Amounts use Decimal128, so money is not stored as a floating point number.

## What it shows

[Dele-Adelusi_Oluwanisola_301910982_queries.js](Dele-Adelusi_Oluwanisola_301910982_queries.js) runs six examples.

1. Sample documents with different fields in the same collection.
2. A `$jsonSchema` validator rejects a document with an invalid type and an amount stored as a double.
3. An index on (customerId, createdAt) for the 5 latest activities of one customer. Without it MongoDB scanned the collection and examined 23,553 documents. With it, it examined 5.
4. An aggregation of the total transferred by category.
5. An `$elemMatch` query for customers whose selfie liveness score is below 0.85.
6. A second copy of the same PostgreSQL transaction is rejected by a unique index on `(pgTxnId, customerId)`.

## Keeping MongoDB in step with PostgreSQL

The two stores hold the same facts, so they can drift apart. [Dele-Adelusi_Oluwanisola_301910982_reconcile.sh](Dele-Adelusi_Oluwanisola_301910982_reconcile.sh) compares the document count and the total in and out for customers 1 to 500. Right after the load they match. After a deposit is committed in PostgreSQL but not yet sent to MongoDB, the check reports a mismatch (23,553 documents against 23,554, and a total 100 higher). So the copy is only eventually consistent.

A real system would not copy by hand. One option is a transactional outbox. The transfer also inserts a row into an outbox table in the same database transaction, and a small relay writes it to MongoDB. If the transfer rolls back, no outbox row exists. If the relay crashes and sends a row twice, the unique index on `pgTxnId` makes the repeat harmless. The other option is change data capture with a tool like Debezium, which reads PostgreSQL's write-ahead log. It needs no application changes but adds a service to run. I have not built either.

## Why MongoDB, and why not everything

The activity feed and KYC documents change shape by type, are read as a whole per customer and are not updated once written. A relational table would need many empty columns or one table per type. Balances and transfers are different. MongoDB has no foreign keys or CHECK constraints, and Portfolio 3 showed how much those rules and row locks protect money. So the balance stays in PostgreSQL and the feed is a copy of what happened. The price is that the same fact lives in two places.

## How to run

Run Portfolio 2's seed first, because the activity is built from its transactions.

```bash
docker compose -f Dele-Adelusi_Oluwanisola_301910982_docker-compose.yml up -d mongo
portfolio-4-nosql/Dele-Adelusi_Oluwanisola_301910982_load.sh
docker exec vant-mongo mongosh --quiet vant_nosql /work/Dele-Adelusi_Oluwanisola_301910982_queries.js
portfolio-4-nosql/Dele-Adelusi_Oluwanisola_301910982_reconcile.sh
```

Screenshots: [Dele-Adelusi_Oluwanisola_301910982_queries.js output](screenshots/Dele-Adelusi_Oluwanisola_301910982_queries.png) and [reconciliation](screenshots/Dele-Adelusi_Oluwanisola_301910982_reconcile.png).
