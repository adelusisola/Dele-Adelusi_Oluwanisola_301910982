# Portfolio 3: Transactions and Concurrency

I used two demo customers, Adaeze and Emeka, who each start with 1,000 NGN. The view `demo_check` shows each stored balance next to the balance their completed transactions add up to, so a wrong balance is easy to spot.

## 1. Commit and rollback

[Dele-Adelusi_Oluwanisola_301910982_01_commit_rollback.sql](Dele-Adelusi_Oluwanisola_301910982_01_commit_rollback.sql) runs three transfers. A transfer of 100 is committed and stays. A transfer of 300 is visible inside the transaction, then rolled back, so the balances return to normal and no transaction row is kept. A transfer of 5,000 from an account holding 900 breaks the `balance >= 0` check, and the whole transfer is undone automatically.

## 2. Lost update

In [Dele-Adelusi_Oluwanisola_301910982_02_lost_update.sh](Dele-Adelusi_Oluwanisola_301910982_02_lost_update.sh), two sessions each withdraw 800 from an account holding 1,000 at the same time.

In the wrong version both sessions read 1,000, both pass the check and both write back 200. Two withdrawals of 800 were recorded, so the balance should be -600, but it is 200. The fix is `SELECT ... FOR UPDATE`. The second session waits, reads 200 and is refused with "insufficient funds", and the balance and the transaction list agree.

## 3. Isolation levels

In [Dele-Adelusi_Oluwanisola_301910982_03_isolation.sh](Dele-Adelusi_Oluwanisola_301910982_03_isolation.sh), session A reads Adaeze's balance twice while session B deposits 500 and commits in between. Under READ COMMITTED the reads are 1,000 then 1,500. Under REPEATABLE READ both reads are 1,000, because the transaction keeps its own snapshot.

## 4. Deadlock

In [Dele-Adelusi_Oluwanisola_301910982_04_deadlock.sh](Dele-Adelusi_Oluwanisola_301910982_04_deadlock.sh), Adaeze pays Emeka while Emeka pays Adaeze. Each transfer locks its source account first and then waits for the other, so PostgreSQL detects the deadlock and cancels one of them. The fix is to lock the two accounts in `account_id` order, and then both transfers complete.

## 5. Idempotent transfer

`transfer_idempotent` in [Dele-Adelusi_Oluwanisola_301910982_05_idempotent_transfer.sh](Dele-Adelusi_Oluwanisola_301910982_05_idempotent_transfer.sh) takes a key chosen by the client. With the same key and the same details, money moves only once. This covers a retry after a timeout and a double tap sent at the same moment, where the second call waits for the first and then finds the key already used. With the same key but different details (`pay-123` reused for 500 instead of 100), the request is rejected, because treating it as a duplicate would silently drop a real transfer.

## Demos against production

Demos 2 and 4 use functions that are wrong on purpose (`withdraw_unsafe`, `transfer_slow`), with `pg_sleep` added to make the race repeatable. They are for teaching, not to deploy. A real transfer would also need:

- an idempotency key stored in the same database transaction as the transfer, as in demo 5
- locks taken in `account_id` order
- a retry loop for deadlocks and serialization errors (40P01 and 40001) that reuses the same key, which I did not build
- a PENDING, COMPLETED or FAILED status, so transfers stuck half-way can be found, plus a regular run of `Dele-Adelusi_Oluwanisola_301910982_invariants.sql`
- `lock_timeout` and `statement_timeout`, so one stuck session cannot block an account for ever

## How to run

```bash
psql -d vant_personal -f Dele-Adelusi_Oluwanisola_301910982_setup.sql
psql -d vant_personal -v adaeze=ID -v emeka=ID -f Dele-Adelusi_Oluwanisola_301910982_01_commit_rollback.sql
./Dele-Adelusi_Oluwanisola_301910982_02_lost_update.sh
./Dele-Adelusi_Oluwanisola_301910982_03_isolation.sh
./Dele-Adelusi_Oluwanisola_301910982_04_deadlock.sh
./Dele-Adelusi_Oluwanisola_301910982_05_idempotent_transfer.sh
```

Run Dele-Adelusi_Oluwanisola_301910982_setup.sql after Portfolio 1. For the first script, ID is the account_id of 9000000001 (Adaeze) and 9000000002 (Emeka). The shell scripts look the ids up themselves.

Screenshots: [commit and rollback](screenshots/Dele-Adelusi_Oluwanisola_301910982_01-commit-rollback.png), [lost update](screenshots/Dele-Adelusi_Oluwanisola_301910982_02-lost-update.png), [isolation](screenshots/Dele-Adelusi_Oluwanisola_301910982_03-isolation.png), [deadlock](screenshots/Dele-Adelusi_Oluwanisola_301910982_04-deadlock.png), [idempotent transfer](screenshots/Dele-Adelusi_Oluwanisola_301910982_05-idempotent-transfer.png).
