# Portfolio 1: Database Design and Modelling

My case study is Vant Personal, a simulated savings app (see the main README). I split the data into five tables: customer, account, savings_goal, beneficiary and transaction.

![ER diagram](er-diagram.png)

## Design

The tables are in [schema.sql](schema.sql). Each has a primary key, and foreign keys link them, so an account cannot exist without a customer. Email, phone and account number are unique, and so is the idempotency key on a transaction, so a repeated request cannot create a second one.

Other rules are checks. A balance cannot go below zero, an amount must be above zero and customers must be 18 or over. A transfer needs a source account and either a destination account or a beneficiary, not both. Each transaction has a currency, and a composite foreign key makes both accounts hold that currency, so NGN cannot go into a USD account.

## Normalisation

If one wide transaction row repeated the customer's name, email and account details, changing an email would mean editing many rows. So customer details are in customer, account details are in account, and a transaction only stores account ids. Every column depends only on its own table's key, which gives 3NF.

I did make one exception. account.balance could be worked out by adding up the transactions, but I store it so reads are fast. The cost is that it must change in the same database transaction as the transaction row (Portfolio 3). The view balance_check and [invariants.sql](invariants.sql) check that the two agree.

## Testing

```bash
createdb vant_personal
psql -d vant_personal -f schema.sql
psql -d vant_personal -f tests.sql
```

[tests.sql](tests.sql) runs 16 checks and prints PASS or FAIL for each. Four check that valid data works, such as a deposit with its balance update. Twelve try to break a rule, such as a duplicate email, a negative balance or a transfer to the same account, and pass only if the database refuses them. I checked the checks themselves by removing the amount rule, and the zero-amount test then reported FAIL.

Screenshots: [tables and constraints](screenshots/tables.png), [the 16 checks](screenshots/constraint-tests.png).
