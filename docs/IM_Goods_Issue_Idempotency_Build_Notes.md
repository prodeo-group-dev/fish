# IM goods-issue idempotency: build notes (IM's side of the SPUTO)

**Status: BUILT, NOT DEPLOYED, 2026-10-07. IM branch `feature/goods-issue-idempotency`, tip `c0cf5be`, with CM for HIGH review.** Companion to `docs/IM_Goods_Issue_Idempotency_SPUTO.md` (SOP's draft, fish PR #136). Covers SPUTO tasks T1-T4 and T7. T5 (SOP) and T6 (POP) are theirs and wait for IM to be deployed and verified.

## What changed against the SPUTO, and why

| Decision | Outcome |
|---|---|
| D1: dedupe on `salesOrderReference` or an explicit key | **Explicit `Idempotency-Key`.** Checked in code: POP's Return Outwards reference is `{purchaseOrderId}#{lineIndex}` (`DispatchReturnOutwardsUseCase.kt:74`), which repeats when a PO line is returned twice. |
| Q3 receipt side | **Parked** (Femi). POP corrected: POP never calls IM's receipt, so that caller is someone else (probably WEB). Re-scoped as IM's own item. |
| Q4 retention | **30 days** (Femi). Safe, see "Crash window" below. |
| Not in the SPUTO: oversell race | **Fixed in the same pass** (Femi): per-Item lock. |
| Not in the SPUTO: crash window | **Fixed**: one transaction, confirmation is the truth. |

## The contract (final, for SOP's T5 and POP's T6)

Optional header `Idempotency-Key` on `POST /api/companies/{companyId}/items/{id}/issue`. Accepted characters `[A-Za-z0-9._:#-]`, 1-200 long. Only a SHA-256 of the key is ever sent to GL.

| Situation | Response |
|---|---|
| New key | issue runs; 200 with the usual body; the answer is stored |
| Same key, identical request, already done | the original 200 body replayed, **same `journalEntryId`**, nothing mutated, GL not called |
| Same key, different request | 422 `idempotency_key_reused` |
| Same key still running | 409 `idempotency_key_in_progress` (retry later, same key) |
| Item busy with another movement for up to 10s | 409 `item_busy` (retry later, same key) |
| GL answers a 4xx (period closed, account missing...) | GL's status with `gl_engine_call_failed`. Definitive: key freed, attempt bumped, so the **same key** can be resent after the cause is fixed and IM sends GL a fresh key itself |
| GL times out or answers 5xx | key freed, attempt NOT bumped, same GL key on retry, so GL replays whatever it did |
| GL answers 422 `idempotency_key_reused` | 409 `gl_idempotency_conflict`. Treated as unknown, never a refusal: bumping could double-post an issue that actually landed |
| No header | exactly as before (still serialised per Item) |

A retry after an unknown outcome must resend an **identical** request. SOP's final key shape `issue:{companyId}:{clientKey}:{attempt}#{lineIndex}` (178 characters worst case) is accepted.

Release modes use the same names SOP uses: STORE, CLEAN (nothing happened), UNKNOWN (outcome unknown at GL), REFUSED (GL definitively refused).

## CM's review checklist, answered

1. **Migration `V9__goods_issue_idempotency.sql`.** New `idempotency_keys` table. On the live `goods_issue_confirmations`: three nullable `ADD COLUMN`s with no default (catalog-only, no rewrite, a momentary ACCESS EXCLUSIVE lock) and a **partial unique index** `(company_id, idempotency_key) WHERE idempotency_key IS NOT NULL`. The index is a plain `CREATE INDEX` because Flyway runs in a transaction: a SHARE lock (blocks writes, not reads) for one scan of a table of a few hundred development rows. Existing rows and no-header calls are outside the partial index. Verified: V1 to V9 migrate on a fresh Postgres 16.15 (production RDS is 16.13).
2. **Per-Item lock.** Session-level `pg_try_advisory_lock(hashtext('im-item:<itemId>'))` on a connection of its own, polled every 25ms up to 10s, held across read, check, GL post and save. Released in a `finally` run under `NonCancellable`, so normal return, an exception and coroutine cancellation all free it. If the unlock itself fails the physical connection is aborted (that ends the session and frees the lock); a process crash does the same. Holders are capped at **half the pool** (default 5 of 10) because each holder needs a second connection for its repository writes; waiting longer than 10s for a slot or the lock gives 409 `item_busy`.
3. **GL refused versus timed out.** See the table above. Verified in GL's `Idempotency.kt` that GL stores every response the route returns (4xx included) and nothing for an exception.
4. **Claim ownership.** Every claim carries a random `claim_token`; `complete` and `release` are `UPDATE ... WHERE claim_token = ? AND state = 'IN_PROGRESS'` and return false when ownership was lost. This is the gap CM found in SOP and HR.
5. **Crash window (not in the SPUTO).** Before this, `RecordGoodsIssueUseCase` saved the Item, the confirmation and the bin balance as three separate transactions, so a crash between them left stock decremented with nothing recording why, and a retry would issue again. Now all three commit together, and the confirmation row carries `(company_id, idempotency_key, journal_entry_id)`. A retry looks the confirmation up **first** and mutates nothing. That is why the 30-day purge of `idempotency_keys` is harmless: the confirmation row, not the key table, is the truth.
6. **Tests.** 241 unit (13 new). 11 new against real Postgres 16, run with a throwaway container so nobody's dev database was touched: eight concurrent claims give exactly one `Claimed`; a stale takeover leaves the old owner unable to complete or release; purge is harmless; a duplicate key rolls back the Item change in the same unit of work; two holders of one Item never overlap while two Items run in parallel; Busy after the wait; release after an exception; **release after cancelling a request whose GL call hangs**; and an **oversell CONTROL**: with no lock, two concurrent issues of 8 from 10 both succeed and the Item ends at 2 (16 issued, GL posted twice); with the lock exactly one succeeds. Mutation-checked: removing the confirmation lookup fails the two crash-recovery tests, removing the token check fails the stale-takeover test.

## Plain statement of the cost

**All issues of one Item serialise behind the GL call.** The lock spans the posting-context lookup, the GL post and the save, so two sales of the same Item cannot run side by side; the second waits up to 10 seconds or gets 409 `item_busy`. Acceptable at SMB volumes, and it is the price of closing the oversell race. Different Items are unaffected.

## Residual risks, stated plainly

- **The lock covers issues only.** Goods receipt, approving an adjustment, and opening stock still do an unlocked read-modify-write on the same Item. An issue running at the same moment as a receipt can still lose an update (stock overstated, not oversold). Same fix, a few lines each now that the lock exists, but it widens the change on live paths, so it is a separate item for Femi to schedule.
- **IM's GL HTTP client has no explicit timeout configured** (no `HttpTimeout` plugin; I did not verify the engine default). A hung GL call holds the Item lock until the client gives up; cancellation frees it (tested), but a never-ending call would not cancel on its own. Recommend a request timeout on the GL client as a one-line follow-up.
- **No compensating undo yet.** Stock issued and then abandoned (SOP's ledger post refused, nothing retried) stays issued. SOP wants a per-line undo-by-reference route, idempotent by key `undo:{companyId}:{clientKey}:{attempt}#{lineIndex}`. Not built; needs its own SPUTO.
- Id-based routes on Items, Locations and Bins already check the record's Company (16 checks, IM PR #7), but POP found an equivalent gap in POP's supplier routes, so IM's Location and Bin routes get a re-check as a separate item.

## Order from here

1. CM reviews and deploys IM (this branch). 2. Verify live: issue with a key twice, expect the same `journalEntryId` and one stock decrement. 3. SOP ships T5, POP ships T6 (with its own retry path and stored posted marker). 4. Undo route SPUTO. 5. Lock on the other Item mutators. 6. Receipt-side idempotency, re-scoped.
