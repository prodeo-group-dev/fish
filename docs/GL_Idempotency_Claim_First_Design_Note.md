# GL idempotency: claiming the key before posting (design note)

**From:** General Ledger (GL) session. **Date:** 2026-10-11. **Status:** DESIGN NOTE, no code. CM's order (item 9): design first, then CM's go before any code. **Written against:** GL master `f47b4c8` plus `7298fe5` (`respondIdempotently` stores only 2xx, awaiting CM release). **Why now:** the GRNI seam work (`docs/POP_IM_GL_Purchase_Posting_Design_GL_Half.md`) makes POP's match and payment retry-heavy money calls, and Femi's SPUTO rule is foundations before features.

## 1. What is safe today, and what is not

`respondIdempotently` (`infrastructure/web/Idempotency.kt`) works in three steps: **find** the stored record for (tenant, endpoint, key); if none, **run** the posting; **store** the response. With `7298fe5` only a 2xx is stored.

| Case | Today |
|---|---|
| Sequential retry after a lost reply | Safe: the stored 2xx is replayed, same journal entry id, nothing posted twice. |
| Sequential retry after a refusal (4xx), cause since fixed | Safe (new in `7298fe5`): the refusal was not stored, the retry runs. |
| Different body, same key, after a success | 422 `idempotency_key_reused`. |
| **Two requests with the same key at the same moment** | **Not safe.** Both pass `find`, both run the posting, both post. Only one record is stored (the unique index and `insertIfAbsent`), so the *storage* is right but the *ledger* has two entries. |
| **A route that persists something and then answers 4xx/5xx** (CM's residual) | **None exists today** (audit, section 5): every refusal precedes the first write. |
| **A thrown exception after a partial write** (aggregate-writing routes only) | Not stored (500), and a keyed retry repeats the persisted part. Section 5 lists the sites. |
| A 5xx or a crash after a successful post but before the record is stored | Retry runs again and posts a second time. (Same family: the post and the key record are two separate writes.) |

The simultaneous-duplicate row, the crash-before-store row and the partial-write row are one defect in three forms: **the claim on the key and the posting are not one atomic act.** The cash book already solved this for its own routes, by a different mechanism (section 2, option A).

## 2. Options

### A. Entry-id claim (the cash book's pattern, extended)
The JournalEntry id is derived from (tenant, endpoint, key) (`UUID.nameUUIDFromBytes`) and written with `insertIfAbsent` (`INSERT ... ON CONFLICT DO NOTHING`). The entry **is** the claim: whoever inserts it posted it, anyone else finds it and replays. There is no pending state and nothing to expire.

- **Good:** no new table; atomic by construction (one insert); proven in production for the cash book (`RecordCashBookEntryUseCase`, `PostJournalEntryUseCase.executeOnce`, `UndoCashBookEntryUseCase`).
- **Limits:** (1) only works where one request creates **one** journal entry and nothing else: it fits record-sale, collection, sales return, obligation, payment, receipt, issue, pay run and post-journal-entry, but not create-sales-invoice, create/depreciate/impair/dispose fixed asset or the leave-accrual calls, which also write their own aggregate (the entry would insert but the aggregate would not be claimed). (2) The entry has no fingerprint, so telling "same request" from "different request with the same key" means rebuilding the comparison per endpoint (the cash book hand-writes `matches` for its three shapes; the thin interfaces compute VAT and group lines, so each needs its own). (3) The replay response must be rebuilt from the stored entry per endpoint.
- **Cost:** about 0.5 day per endpoint family, nine endpoints, plus per-endpoint comparison logic: roughly 4 to 5 days, and a long tail of subtle "same request?" rules.

### B. Pending row with a lease
Insert the `idempotency_keys` row first as PENDING (unique index = the claim), run the posting, then fill in the response; a second request that sees PENDING answers 409 `request_in_progress`. A claim whose owner crashed is taken over after a lease (for example 60 seconds).

- **Good:** works for every endpoint whatever it writes; fingerprint stays where it already is.
- **Limits:** a takeover after a crash can double post if the first owner had actually posted before dying, unless the post itself is also keyed (so it needs option A's id as well, for belt and braces). Needs a status column (migration), a lease clock, a sweeper or lazy takeover, and new client-visible behaviour (409 in progress). Most moving parts of the three.
- **Cost:** about 3 days plus the per-endpoint keying anyway.

### C. Claim and post in one database transaction (recommended)
Run the whole request, key claim included, inside **one** transaction:

1. Open a transaction; `SET LOCAL lock_timeout = '5s'`.
2. `INSERT INTO idempotency_keys (..., fingerprint, response = placeholder) ... ON CONFLICT DO NOTHING`. If a concurrent transaction holds the same key, Postgres makes this statement **wait** until that transaction commits or rolls back, then decides. If it conflicts: read the committed row and replay it (same fingerprint) or answer 422 (different fingerprint). If the wait times out: 409 `request_in_progress`, nothing written.
3. If we own the key: run the posting (the existing use case, unchanged).
4. If the result is 2xx: write the response onto the row and **commit**. If not 2xx: **roll the whole transaction back**, claim and any partial writes with it, and respond with the refusal.

- **Good:** closes all three rows of section 1 at once. Two simultaneous requests serialize on the unique index (one posts, the other replays). A failure after a partial write (a refusal, should one ever be added, or an exception) leaves nothing, which closes CM's "persist then refuse" residual for good and the exception-path partial writes the audit found in the aggregate-writing routes. A crash before commit leaves nothing (no stale pending row, no lease). No new table, no migration, no client-visible change except the rare 409 on a stuck duplicate. Works for every endpoint, including the ones that also write an aggregate. The existing use cases and routes' result mapping are unchanged: only the helper changes.
- **Limits and risks, to be settled by a spike (S1) before any build:**
  1. **Joining the transaction.** The repositories each call `transaction { }`; Exposed joins an enclosing transaction by default. GL already relies on that (`recordReversal`'s comment: "inside this one they join it, so all of it commits or none of it does"). The produceResponse lambda is `suspend`; it must run on one thread inside the transaction. Candidates: make the lambda blocking, or Exposed's `newSuspendedTransaction` (confirm nested `transaction { }` calls inside it join). This is the main technical unknown.
  2. **Connection held across the request.** A waiting duplicate holds a Hikari connection while it waits (bounded by the 5 s lock timeout). Duplicates are rare; the pool is sized for normal traffic; the lock timeout caps the cost. Measure in the spike.
  3. **Side effects that are not database writes.** If any lambda does something that cannot be rolled back (an outbound call, an event published before commit), rollback would not undo it. The audit in section 5 checks for this; the use cases return domain events to the caller and the routes appear not to publish them, to be confirmed in the spike.
  4. **No real-Postgres route tests today.** GL's route and use-case tests run on in-memory fakes, which cannot prove transactionality or lock behaviour. Jenkins already starts a `postgres:16` container for the build (`FISH_DB_*`), so a small integration suite is possible but is new test infrastructure, part of the spike.
  5. **Behaviour change on every money route**, so the review is HIGH and the rollout is the pattern the cash book used: ship, watch the logs, no consumer change needed.
- **Cost:** spike 0.5 day; build about 2 days (helper rewrite, an integration-test harness, concurrency and rollback tests); HIGH review.

### D. Do nothing further
Accept the narrow race. Defensible while every caller retries sequentially, which POP's seam H does. Not recommended once WEB and POP can both reach the same route (a double click racing a retry), and it leaves the persist-then-refuse residual open.

## 3. Recommendation

**Option C, behind a spike.** It is the only one that removes all three failure forms without per-endpoint rules, a status column or a lease. Option A stays as is for the cash book (it already works and is cheaper there). If the spike shows that joining the transaction inside Ktor's coroutine handling is not reliable, the fall back is **A for the nine single-entry endpoints** (the money ones that matter: sale, collection, sales return, obligation, payment, receipt, issue, pay run, post-journal-entry) and the current behaviour for the aggregate-writing ones until their own use cases are made at-most-once.

## 4. Order and what is needed from CM

1. `7298fe5` released (G1). Nothing below depends on it being deployed first, but the tests assume it.
2. **CM's go** on this note, then spike S1 (0.5 day): a throwaway branch proving (a) nested repository `transaction { }` calls join the helper's transaction under `newSuspendedTransaction` or a blocking variant, (b) two simultaneous same-key requests against real Postgres produce one entry, (c) a lambda that saves and then refuses leaves nothing. If S1 passes, build option C (about 2 days) on the shared helper; HIGH review; deploy log-first is not applicable (no flag), so deploy during a quiet sitting and watch for `request_in_progress` and connection-pool warnings.
3. The GRNI build (the GL half note) does **not** wait for this: its retry safety is the sequential case, already covered by `7298fe5`. This note is the gate before any caller is allowed to retry concurrently.

## 5. Audit: routes that persist and then refuse (CM's request)

Method: every `respondIdempotently` lambda (**16 call sites** in 9 route files, not 18: 17 grep hits include the helper's own definition) was read together with the use case it calls, and the key claims were re-checked against the source by hand (the leave-accrual order and the fixed-asset and sales-invoice write sequences).

**Result 1: no "persist then refuse" path exists today.** In every use case, every non-2xx outcome (invalid amount, Period or account not found, Period not open, unsupported VAT category, nothing to change) is returned **before the first repository write**. The route-level refusals (tenant, authorization, parsing, the settlement-account policy) all run before `respondIdempotently`, outside the lambda. So CM's residual, as worded, is empty: item 8 cannot cause a duplicate through a refusal.

**Result 2: there is no cross-repository transaction anywhere.** Each repository method opens its own `transaction { }` and no use case or route wraps several calls in one. So a **thrown exception** (a 500, which is also not stored) after a partial write can leave partial state, and a keyed retry would repeat the persisted part:

| Call site | Write order | What a failure part-way leaves | A retry |
|---|---|---|---|
| Create sales invoice (highest risk) | accounts, customer, journal entry, invoice record, then a read of the company name | entry and customer balance persisted, no invoice record; or everything persisted and a 500 from the trailing read | new entry id, customer balance raised a second time |
| Create fixed asset | journal entry (inside `PostJournalEntryUseCase`), then the asset | posted entry, no asset | a second entry |
| Depreciation, impairment, disposal | journal entry, then the asset's new state | posted entry, asset state not updated | recomputes from the stale asset and posts again |
| Leave accrual remeasure and utilize | accrual balance **first**, then the journal entry | balance changed, no entry | utilize deducts again; remeasure answers "no change" |
| Sale, collection, sales return, obligation, payment, receipt, issue, pay run, post-journal-entry | accounts' activity flag, then one journal entry | only a harmless, idempotent `hasPostedActivity = true` | safe |

So the nine thin posting interfaces (the money ones the GRNI seam uses) are safe on this axis, and the aggregate-writing ones (sales invoice, fixed assets, leave accruals) are not. Writing the failure risk out plainly: these have been this way since they were built, nothing in item 8 makes them worse, and none has been seen failing in production.

**What this means for the options:** option C (section 2) is the only one that closes this as well, because rolling the transaction back also removes the partial writes. Option A cannot (it claims only the entry). The cheaper alternative for these aggregate-writing sites alone is to reorder (entry last, state before it) so the failure leaves the harmless side, but that is per-use-case work and still leaves a window.

## 6. Tests (for the build, not now)

- **Concurrency (real Postgres):** N simultaneous requests with the same key and body produce exactly one journal entry; all N responses carry the same entry id.
- **Rollback (real Postgres):** a use case that saves an Account and then refuses leaves the Account unchanged and no entry, and the key is free.
- **Replay and reuse:** a lost reply replays; a different body after a success is 422; a refusal then a fix posts once.
- **Timeout:** a duplicate that waits longer than the lock timeout answers 409 `request_in_progress` and writes nothing.
- **Mutation checks:** removing the transaction, the `ON CONFLICT DO NOTHING`, or the rollback on non-2xx must each fail at least one test.
