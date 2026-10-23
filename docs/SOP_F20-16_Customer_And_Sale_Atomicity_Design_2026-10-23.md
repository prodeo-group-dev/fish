# F20-16: the customer a failed sale leaves behind, and what a failed ledger post or stock issue leaves behind (design note, SOP session, 2026-10-23)

**Status: DESIGN ONLY. Nothing is built. For Femi's decision via CM (Femi's architecture follow-up 5).** Written from SOP master `6079483` plus the branches in review (`4074f78`, `70b0993`), `docs/reports/ADR_Microservices_Architecture_2026-10-18.md` and `Downloads/microservices-architecture-brief.md`. The PDF `RT_FiSH_Microservices_Architecture_Research_2026-10-23` could not be opened here (no PDF reader), so its sections 4 and 5 are NOT quoted; the brief and the ADR are the sources used. Where this note says "checked in code" it was read, not recalled.

## 1. Scope (S)

**The finding.** F20-16 (Major, SOP, due 25 Oct): "customer-create ... isn't atomic, so the customer is created even when the sale fails ('UAT B2 Customer')". Filed from CM's review of the F20-11 hotfix, as a separate change.

**What it really is (checked in code).** `POST /api/sales` **never creates a customer**: it needs an existing `customerId` and answers `404 customer_not_found` for a missing or foreign one. The customer is made by the screen: WEB's sale form calls `POST /api/companies/{id}/customers` first (the "quick customer" and the walk-in customer, `SalesTab.tsx` around lines 303 to 320) and only then `POST /api/sales`. So the write that is not atomic is a **two-call sequence driven by the browser**: call 1 commits a Customer in SOP's database; call 2 (the sale) may then be refused, by SOP's own checks, Inventory, or the ledger, and call 1 is never undone.

**In scope.** (a) Making "create the customer and sell to them" one operation that leaves no customer behind when the sale does not happen. (b) Stating, for each step of a sale, what a failure leaves behind today and under each option. (c) The order to build it in.

**Not in scope.** Collections, credit notes, the VAT work (F22-18), per-line stock keys' own build (T5, but see section 2: it is a precondition), the Education Runtime (suspended).

## 2. What exists today (facts, checked in code)

**Customer creation is already safe to repeat.** `CreateCustomerUseCase` takes an optional `Idempotency-Key` and a request fingerprint; `createOnce` records the key against the Customer it created, so the same key and request return the same Customer (`200` replay) and the same key with a different request is refused. A refused request never spends the key.

**The sale, in order** (`RecordOrdinarySaleUseCase`, then `RecordSaleUseCase`), and what a failure at each step leaves behind **today**:

| Step | If it fails | What is left behind today |
|---|---|---|
| 0. Customer made by WEB (separate call) | n/a | The Customer exists from now on, whatever happens next. **This is F20-16.** |
| 1. Read the posting context, check currency, items, prices, VAT rates (F22-18: SOP now works the VAT out here) | Refused with a plain reason | Nothing from the sale. The customer from step 0 stays. The Idempotency-Key is free. |
| 2. IM stock issue, one call per stock line, in order | Line k refused, or IM unreachable | Lines before k are **already issued and not returned** (the answer says "check the stock in Inventory before trying again"); nothing in the ledger; no order; the customer stays. |
| 3. Ledger post (`record-sale`, one journal entry) | GL refuses (4xx) or is unreachable | All stock lines **stay issued**; no journal; **no order saved** (an order is saved only once the ledger accepted); the customer stays. A GL 4xx frees the key for a fresh GL key; a timeout keeps the same key, so a retry replays GL's original posting instead of posting twice. |
| 4. Save the order (SOP's own database) | The database is down or rejects | The ledger **has** the sale and IM has the issue; SOP has no order. A retry with the same Idempotency-Key rebuilds the same order id and GL replays its posting, so it converges. |
| 5. Cash sale only: the collection (a second ledger post) | Refused or lost | The sale is recorded; the answer is `502 sale_recorded_not_collected`, finished through the collections route with the same key. |

**A precondition found while writing this (T5).** `ImGateway.recordGoodsIssue` on master carries **no idempotency key**: SOP does not forward one to IM's issue route. IM made its issue idempotent on an explicit header key (not on the sale reference), so a retried sale that re-runs step 2 **issues the stock a second time**. That is why the answer tells the person to check Inventory first. The fix, per-line keys derived from the sale (`feature/t5-stock-issue-keys`, local, never merged), is what makes steps 2 to 4 converge on retry. Whatever is chosen below, **T5 should land first**: without it no option makes a retry safe.

## 3. Requirements (P)

IDs proposed `FR-SOP-ATOM-nn`, for Femi's approval with this note.

- **FR-SOP-ATOM-01.** A sale that is refused, or that fails before the ledger accepts it, leaves **no Customer created for that sale**.
- **FR-SOP-ATOM-02.** A retry of the same sale (same Idempotency-Key) after any failure converges: one Customer, one order, one ledger posting, one stock issue per line.
- **FR-SOP-ATOM-03.** No state is invented that the person has to understand (no "pending customer" that shows in lists or on an invoice).
- **FR-SOP-ATOM-04.** The existing standalone customer routes keep working unchanged; a sale to an existing customer is unchanged.
- **FR-SOP-ATOM-05.** What a failed stock issue or ledger post leaves behind is stated in the answer and can be finished by retrying, never by editing data (Prodeo is a landlord: it does not repair a Tenant's records).

## 4. Options

### A. The customer is created inside the sale, in the sale's own local transaction (recommended)

`POST /api/sales` accepts, instead of `customerId`, an optional `newCustomer {name, creditTerms, ...}` (additive; exactly one of the two is allowed). SOP validates the new customer's fields first (name, credit terms), derives **deterministic ids** from the Idempotency-Key (the customer id and the order id), runs steps 1 to 3 as today, and writes **the Customer and the order together in one local database transaction at step 4**, after the ledger has accepted the sale. The ledger already identifies the customer by id only, so posting before the customer row exists is safe: the id is the same on a retry.

- A refusal at step 1, 2 or 3 leaves **no customer** (FR-SOP-ATOM-01).
- A failure at step 4 leaves the ledger and IM done and no customer or order; the retry (same key) rebuilds the same ids, GL replays, IM replays (once T5 is in), and the local write succeeds (FR-SOP-ATOM-02).
- Reuses the creation-key mechanism for the customer; no new states (FR-SOP-ATOM-03).
- Cost: SOP use case and route change (additive request field), WEB stops the two-call flow for quick and walk-in customers, one contract fixture pair (consumer-first). About 2 days SOP plus WEB's share. No migration if the creation-key table already allows a derived key.
- Residual risk: a customer name typed twice in two different sales creates two customers (as today). The walk-in customer should become a normal existing customer that WEB reuses, not a per-sale `newCustomer`.

### B. A saga with compensation (provisional customer)

Keep the two calls. The first call creates the Customer as `PROVISIONAL`; the sale's success confirms it; a failed sale, or a reaper after N minutes, removes it (the compensation).

- A refusal leaves a provisional customer until the reaper runs (not "no customer" at once), and the reaper can race a slow retry that is about to confirm it.
- Adds a status that every list, invoice and report must hide or explain (FR-SOP-ATOM-03), a scheduled job, and a delete path for a Customer, which does not exist and which raises "what if something already references it".
- Cost: higher than A, for a weaker guarantee. **Not recommended.**

### C. A transactional outbox with asynchronous posting

SOP writes the Customer, the order and a "post this to the ledger" intent in **one local transaction**, answers at once, and a relay posts to GL (and issues to IM) with the sale's keys until it succeeds. This is the pattern in the architecture brief for "update the database and publish atomically", and it is what a failed ledger post or stock issue would look like in the long run: nothing is lost, the order shows `POSTING` until the ledger confirms.

- After F22-18 SOP knows net, VAT and gross before posting, so the money figures no longer depend on the ledger's answer; that makes C possible where it was not.
- But it changes what "the sale is recorded" means: an order exists before the ledger has accepted it, the stock check against Inventory still has to be synchronous (availability), and a ledger refusal after the answer needs a visible `FAILED` state with a way to fix or cancel. It is the right long-term direction for steps 2 and 3, and the wrong size for F20-16.
- Cost: weeks, plus WEB and EA changes. **Recommended as a separate decision**, not as the fix for this finding.

## 5. Recommendation and order (O)

1. **T5 first** (per-line stock keys; already written on `feature/t5-stock-issue-keys`; needs a rebase on current master and IM's confirmation that its issue route honours the key). Without it a retry double-issues stock under every option.
2. **Option A** for F20-16: additive `newCustomer` on `POST /api/sales`, ids derived from the key, customer and order written together at step 4. Fixtures first; WEB and the Education Runtime declare the request field before release; WEB then uses it for the quick and walk-in customers.
3. **Option C** is recorded as the long-term answer for the cross-service steps and goes to Femi as its own decision with the architecture research; it does not block A.
4. Existing orphan customers (for example "UAT B2 Customer") are Tenant data: SOP does not remove them. Whether a "delete a customer with no orders" action is wanted is a product decision for Femi, separate from this fix.

## 6. Use cases (U)

- **UC-SOP-ATOM-1 Quick customer, sale refused.** The person enters a new customer's name and a sale; the ledger refuses (closed period). Nothing is created for them; they fix the period and send the same sale again.
- **UC-SOP-ATOM-2 Quick customer, sale posts, the local save fails.** The ledger and Inventory are done; SOP answers an error; the identical retry succeeds with the same customer and order, and the ledger shows one posting.
- **UC-SOP-ATOM-3 Existing customer.** Unchanged.
- **UC-SOP-ATOM-4 The same sale sent twice at once.** One customer, one order; the second request waits or replays (claim-first key).

## 7. Tasks (T)

| Task | Does | Depends on |
|---|---|---|
| T-ATOM-01 | Land T5: per-line IM keys on a sale's stock issue | IM confirms the key is honoured; rebase |
| T-ATOM-02 | Contract first: fixtures for `newCustomer` request and its refusals; WEB and ER declare | Femi's decision |
| T-ATOM-03 | `RecordOrdinarySaleUseCase` accepts `newCustomer`; ids from the key; customer and order saved in one transaction after the ledger accepts | T-ATOM-01, T-ATOM-02 |
| T-ATOM-04 | WEB uses it for quick and walk-in customers; stops the two-call flow | T-ATOM-03 released |
| T-ATOM-05 | Tests: every step's failure leaves what section 4A says (mutation-checked), retry converges | with T-ATOM-03 |

## 8. Decisions needed from Femi

1. **Option A (recommended), B or C for F20-16?**
2. Is **Option C** (asynchronous posting with an outbox) wanted as the long-term direction, as a separate piece of work?
3. Should a customer with no orders be deletable by the Tenant's own administrator?
4. Confirm **T5 first**, since no option makes a retry safe without it.
