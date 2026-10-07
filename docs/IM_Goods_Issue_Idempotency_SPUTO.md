# IM goods-issue idempotency — SPUTO (Scope / Plan / Use cases / Tasks / Order)

**Status: DRAFT, 2026-10-07, SOP session. Planning only — nothing built.** Drafted at Femi's direction ("Let's work with IM to sort this out. It might need a SPUTO") after the gap was found while building SOP's client `Idempotency-Key` support. **No IM session was live when this was written**; it needs an IM owner (or Femi's explicit go for SOP/CM to build it in `IM/`) before any code. Coordination: register a row in `docs/GL_POP_IM_SOP_Coordination.md` before starting.

## 1. Scope

**The problem.** `IM`'s `RecordGoodsIssueUseCase` (`POST` goods-issue, called by SOP on every stock-tracked sale line and by POP on every Return Outwards) has no duplicate protection at all. Every call runs `Item.recordIssue` (consuming stock/FIFO layers), posts to GL, and saves a `GoodsIssueConfirmation`. A repeat of an already-completed issue issues the stock again.

**How it bites.** SOP now sends a client `Idempotency-Key` on `POST /api/sales` and derives the Sales Order id from it, so a retried sale re-sends the *same* issue call. The failure window: IM issues the stock (saved, GL posted), then something later fails or the response is lost (GL sale posting outage, a timeout between SOP and IM) → the client retries → IM issues again. SOP's own order, its GL sale posting and its cash collection are retry-safe; stock-tracked lines are not. It is pre-existing (a plain double click did the same before), not made worse by SOP's change, but it caps how safe a stock-line sale is to retry.

**In scope.** Making IM's goods **issue** retry-safe for callers that opt in; SOP forwarding a derived key per line; the same for POP's Return Outwards call.

**Out of scope here (noted, not decided).** The symmetric **receipt** side (`RecordGoodsReceiptUseCase`, called by POP on goods receipt): same shape, same fix, parked until the issue side proves the pattern. Retrofitting every other IM route. A shared "idempotency" library across services.

## 2. Plan (requirements)

| # | Requirement |
|---|---|
| R1 | An issue call that carries an `Idempotency-Key` and repeats a completed call (same key, same request) returns the original result (original `journalEntryId`, confirmation) **without** mutating the Item, the bin balance, or GL again. |
| R2 | Same key, **different** request (item, quantity, date, contra account, bin) is refused (422, as GL/SOP do), never silently treated as a replay. |
| R3 | Two concurrent requests with the same key execute **once** (claim-first under an advisory lock, same shape as SOP's `Idempotency-Key` and email claim). |
| R4 | The derived key IM forwards to GL's `inventory/record-issue` is scoped so GL (which scopes keys per Tenant, not per IM/Company) cannot collide across Companies; GL keeps keys forever, so GL is the final backstop. |
| R5 | A call **without** the header behaves exactly as today (additive; no caller breaks). |
| R6 | A GL definitive refusal (4xx, which GL caches under its key) frees the key and bumps an attempt number so a corrected resubmission gets a fresh GL key; a 5xx/timeout reuses the same GL key (outcome unknown). Same rule SOP uses. |
| R7 | Only a hash of the request is stored, never the body; stored replay carries ids and amounts only; nothing logged; 30-day retention with an opportunistic purge. |

### Decision D1 (the one real design fork): dedupe on `salesOrderReference`, or on an explicit key?

**Recommend an explicit `Idempotency-Key`, NOT the reference.** Checked in code: SOP's reference is `{salesOrderId}#{lineIndex}`, and **POP's Return Outwards reference is `{purchaseOrderId}#{lineIndex}`** (`DispatchReturnOutwardsUseCase`) — a PO line can legitimately be returned in more than one dispatch, so "same reference ⇒ same issue" would wrongly refuse a genuine second return. A reference names *what the issue is about*; a key names *this attempt*. An explicit key also matches GL's and SOP's established pattern and is opt-in (R5). Alternative (unique index on reference) rejected for that reason and because historical data may already hold repeats.

## 3. Use cases

- **UC-1 Sale retried after a downstream failure.** SOP's sale: IM issue succeeds, GL sale posting fails 503; client retries with the same key → SOP re-sends issue with the same derived key → IM replays, no second issue.
- **UC-2 Response lost.** IM issued and answered, SOP timed out; SOP's retry replays.
- **UC-3 Double click** reaching IM twice → exactly one issue.
- **UC-4 Same key, changed request** → 422, nothing issued.
- **UC-5 No key** (older callers, manual calls) → unchanged behaviour.
- **UC-6 Concurrent identical requests** → one executes, the rest replay or get a retry-later 409.
- **UC-7 GL refuses the issue (e.g. period closed)** → key freed with attempt bump; after the cause is fixed the same logical request can run.
- **UC-8 Return Outwards retry (POP)** → same protection for the second caller, with POP forwarding its own derived key.

## 4. Tasks

| Task | Where | Notes |
|---|---|---|
| T1 | IM migration | `idempotency_keys` table, same shape and documented retention as SOP's `V14__idempotency_keys.sql` (scope: endpoint + key; IM serves one Company per deployment, include `company_id` if/when that changes). |
| T2 | IM | `IdempotencyKeyRepository` (claim/complete/release with attempt bump), Exposed implementation under an advisory lock; fake for tests. |
| T3 | IM | Optional `Idempotency-Key` header on the goods-issue route; claim before `RecordGoodsIssueUseCase`, store terminal 2xx replay, release on 4xx/5xx per R6. |
| T4 | IM | Forward a derived key (`issue:{key}` + attempt suffix) to `GlEngineGateway.recordInventoryIssue` as GL's `Idempotency-Key`. |
| T5 | SOP | `ImGateway.recordGoodsIssue` sends a per-line key `issue:{companyId}:{saleKey}#{lineIndex}` when the sale has a key. |
| T6 | POP | Same for `DispatchReturnOutwardsUseCase`'s issue call (POP's own return-outwards retry story). |
| T7 | all | Tests: replay, 422, concurrent claim (unit **and** real Postgres, mutation-checked like SOP's), GL-4xx bump, no-key unchanged. |
| T8 | docs | Update the Backlog row, the IM README/MVP doc. |

## 5. Order (dependencies — foundations first)

1. **T1, T2, T3, T4, T7 (IM)** — the guarantee itself. Ship and verify IM first.
2. **T5 (SOP)** — only then does a keyed sale become stock-line retry-safe. Safe to ship before IM too (old IM ignores the header), but protects nothing until step 1.
3. **T6 (POP)** — independent of SOP; same IM guarantee.
4. **T8** — docs.
5. **Parked follow-up:** receipt-side idempotency (POP → IM goods receipt) once this pattern is proven.

**Cross-cutting rule (Femi, 2026-10-07):** foundations are ordered before the features that need them. This item is that rule applied after the fact; SOP's cash route stays held by WEB until SOP's own idempotency is deployed and verified.

## 6. Open questions for Femi / the IM owner

1. Confirm D1 (explicit key, not the reference).
2. Who builds it: the IM session when it next runs, or may SOP/CM build it in `IM/` now (shared-checkout and push rules: only CM pushes/deploys)?
3. Should the receipt side be done in the same pass instead of parked? (Same code shape; larger blast radius.)
4. Is 30 days the right retention for stock keys, or should it match GL's (forever)?
