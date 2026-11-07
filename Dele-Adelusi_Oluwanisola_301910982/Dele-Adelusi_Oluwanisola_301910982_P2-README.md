# Portfolio 2: Query Processing and Optimisation

## Data

[seed.sql](seed.sql) loads 5,000 customers, 7,000 accounts, 2,000 savings goals and 205,000 transactions. It uses a fixed date (7 November 2026) so every run builds the same data and [results.txt](results.txt) can be reproduced. Each balance is worked out from its completed transactions, and [invariants.sql](../portfolio-1-database-design/invariants.sql) found 0 violations ([screenshot](screenshots/invariants.png)).

## Queries

The five queries are in [queries/](queries/). They return the same results with and without the indexes.

| Query | What it does |
|---|---|
| Q1 | the 10 latest transactions of one account |
| Q2 | monthly totals by transaction type |
| Q3 | top 10 customers by total withdrawn |
| Q4 | savings goal progress |
| Q5 | oldest pending transactions |

## Indexes

[indexes.sql](indexes.sql) adds three indexes: `ix_txn_from` and `ix_txn_to` on the account and date columns for Q1, and a partial index `ix_txn_pending` that holds only the pending rows for Q5.

## Plans and timings

The `EXPLAIN (ANALYZE, BUFFERS)` plans are in [plans/before](plans/before) and [plans/after](plans/after). I ran each query 5 times and the table shows the median, the range and the pages read.

| Query | Before: median ms (range) | After: median ms (range) | Pages before | Pages after |
|---|---|---|---|---|
| Q1 | 10.94 (9.00 to 12.99) | 0.16 (0.13 to 0.68) | 2,366 | 66 |
| Q2 | 129.50 (127.42 to 252.67) | 119.62 (117.03 to 136.70) | 3,177 | 3,177 |
| Q3 | 36.06 (35.57 to 36.85) | 35.60 (35.26 to 35.70) | 2,554 | 2,554 |
| Q4 | 1.78 (1.75 to 1.85) | 1.82 (1.67 to 2.02) | 151 | 151 |
| Q5 | 10.27 (9.50 to 10.40) | 0.06 (0.04 to 1.03) | 2,400 | 22 |

## Analysis

Q1 and Q5 got much faster, about 70 and 170 times. Both want a few rows out of 205,000. Before the indexes Postgres scanned the whole table, and afterwards it read only the matching rows, so pages read dropped from about 2,400 to 66 and 22.

Q2 and Q3 did not change because they need most of the table, so the planner correctly kept the sequential scan. Q4 only touches two small tables.

Timings vary between runs. The first Q2 run took 252 ms against a median of 130 ms, so a difference of about 10% (Q2 at 129.5 and 119.6 ms) is just noise. The pages read do not vary, so they are the better evidence for why Q1 and Q5 improved.

## Cost of the indexes

[index_overhead.sql](index_overhead.sql) measures this ([screenshot](screenshots/index-overhead.png)). The table is 18 MB, the two main indexes take about 6 MB each and the partial index 64 kB. Inserting 100,000 rows took 1.2 to 1.5 seconds with the indexes and 0.7 to 0.8 seconds without, so writes were roughly 1.5 to 2 times slower. A busy table like transaction should only carry indexes that real queries need, which is why I added three and not one per column.

## Would production look different?

Yes. The whole table fits in memory here, so nothing was read from disk. In production, avoiding thousands of page reads would save real disk reads and the gain would look bigger. The queries also ran alone with no writes competing, and the seed spreads transactions evenly, while real accounts are uneven. The shape of the plans (scan against index) would carry over, but the exact milliseconds would not.

## How to run

```bash
psql -d vant_personal -f ../portfolio-1-database-design/schema.sql
psql -d vant_personal -f seed.sql
./run_plans.sh before
psql -d vant_personal -f indexes.sql
./run_plans.sh after
./timings.sh
psql -d vant_personal -f index_overhead.sql
```

Screenshots: [timings](screenshots/timings.png), [Q1 plan before and after](screenshots/plan-q1-before-after.png), [query results](screenshots/results.png).
