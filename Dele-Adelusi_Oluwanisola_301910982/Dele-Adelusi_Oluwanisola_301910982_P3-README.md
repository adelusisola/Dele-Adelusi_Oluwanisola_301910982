# Portfolio 3: Transactions and Concurrency

I used two demo customers, Adaeze and Emeka, who each start with 1,000 NGN. The view `demo_check` shows each stored balance next to the balance their completed transactions add up to, so a wrong balance is easy to spot.

## 1. Commit and rollback

[01_commit_rollback.sql](01_commit_rollback.sql) runs three transfers. A transfer of 100 is committed and stays. A transfer of 300 is visible inside the transaction, then rolled back, so the balances return to normal and no transaction row is kept. A transfer of 5,000 from an account holding 900 breaks the `balance >= 0` check, and the whole transfer is undone automatically.

## 2. Lost update

In [02_lost_update.sh](02_lost_update.sh), two sessions each withdraw 800 from an account holding 1,000 at the same time.

In the wrong version both sessions read 1,000, both pass the check and both write back 200. Two withdrawals of 800 were recorded, so the balance should be -600, but it is 200. The fix is `SELECT ... FOR UPDATE`. The second session waits, reads 200 and is refused with "insufficient funds", and the balance and the transaction list agree.

## 3. Isolation levels

In [03_isolation.sh](03_isolation.sh), session A reads Adaeze's balance twice while session B deposits 500 and commits in between. Under READ COMMITTED the reads are 1,000 then 1,500. Under REPEATABLE READ both reads are 1,000, because the transaction keeps its own snapshot.

## 4. Deadlock

In [04_deadlock.sh](04_deadlock.sh), Adaeze pays Emeka while Emeka pays Adaeze. Each transfer locks its source account first and then waits for the other, so PostgreSQL detects the deadlock and cancels one of them. The fix is to lock the two accounts in `account_id` order, and then both transfers complete.

## 5. Idempotent transfer

`transfer_idempotent` in [05_idempotent_transfer.sh](05_idempotent_transfer.sh) takes a key chosen by the client. With the same key and the same details, money moves only once. This covers a retry after a timeout and a double tap sent at the same moment, where the second call waits for the first and then finds the key already used. With the same key but different details (`pay-123` reused for 500 instead of 100), the request is rejected, because treating it as a duplicate would silently drop a real transfer.

## Demos against production

Demos 2 and 4 use functions that are wrong on purpose (`withdraw_unsafe`, `transfer_slow`), with `pg_sleep` added to make the race repeatable. They are for teaching, not to deploy. A real transfer would also need:

- an idempotency key stored in the same database transaction as the transfer, as in demo 5
- locks taken in `account_id` order
- a retry loop for deadlocks and serialization errors (40P01 and 40001) that reuses the same key, which I did not build
- a PENDING, COMPLETED or FAILED status, so transfers stuck half-way can be found, plus a regular run of `invariants.sql`
- `lock_timeout` and `statement_timeout`, so one stuck session cannot block an account for ever

## How to run

```bash
psql -d vant_personal -f setup.sql
psql -d vant_personal -v adaeze=ID -v emeka=ID -f 01_commit_rollback.sql
./02_lost_update.sh
./03_isolation.sh
./04_deadlock.sh
./05_idempotent_transfer.sh
```

Run setup.sql after Portfolio 1. For the first script, ID is the account_id of 9000000001 (Adaeze) and 9000000002 (Emeka). The shell scripts look the ids up themselves.

Screenshots: [commit and rollback](screenshots/01-commit-rollback.png), [lost update](screenshots/02-lost-update.png), [isolation](screenshots/03-isolation.png), [deadlock](screenshots/04-deadlock.png), [idempotent transfer](screenshots/05-idempotent-transfer.png).
