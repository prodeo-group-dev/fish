# Purchase receipt and match posting (the GRNI seam): GL's half (SPUTO)

**From:** General Ledger (GL) session. **Date:** 2026-10-11. **Status:** DRAFT for Femi's approval as a Playbook part. Docs only: **no GL code is written until Femi approves this** (CM, 2026-10-11). **Written against:** GL master `f47b4c8` (GL :119 plus fixes), POP's half `docs/POP_IM_GL_Purchase_Posting_Design_POP_Half.md` (sections 1 to 10, including POP's proposed IM half I1 to I9). IM's own half and IM's product-VAT SPUTO are being written in parallel and are not read here; where this note depends on an IM answer it says so.

Form: Femi's SPUTO (Scope, Plan/SRS, Use cases, Tasks, Order), so the three services have one Playbook to build against.

---

## 1. Scope (S)

**The problem (seam A, verified in the code, not assumed).** For one stock purchase that is both received in IM and matched in POP, the ledger today records the payable twice:

| Step | Who | Debit | Credit |
|---|---|---|---|
| Goods received | IM (`POST /inventory/record-receipt`, contra defaults to the AP control account in IM) | Inventory | **Accounts Payable** |
| Three-way match | POP (`POST /purchasing/record-obligation`) | **lowest-coded EXPENSE account** (what `purchase-posting-context` returns) for the net, plus input VAT to the VAT control account | **Accounts Payable** for the gross |

A 45,000 purchase shows 90,000 owed, inventory 45,000 and an expense of 45,000. Services and unlinked purchases are correct (only POP's step runs).

**What GL owns in the fix.** GL does not decide which lines are stock (POP's `itemId` rule) or what the receipt costs (IM's cost). GL owns only:
1. the **accounts** the two sides meet in (GRNI and a price-variance account);
2. a way for a consumer to **find those accounts** without breaking its strict decoder;
3. a **per-line debit account** on `record-obligation`, so one atomic entry can debit GRNI for stock lines and an expense/asset account for the rest;
4. the **price variance** posting when the invoice differs from what was received;
5. **idempotency** strong enough that match and payment can be retried safely (seam H).

**Out of scope here:** which lines are stock and the receipt link (POP), what IM records as cost, the receipt endpoint's own idempotency (IM, I7), returns outwards beyond the contra rule in FR-GR30, partial payments (POP T8), multi-currency receipts (needs the IAS 21 design, `docs/GL_Foreign_Currency_Accounts_IAS21_Design.md`), a GRNI ageing or clearing report (listed as open question Q-G6).

**Why GL is small here.** `RecordSupplierObligationUseCase`, `RecordInventoryReceiptUseCase` and `RecordInventoryIssueUseCase` are already "debit whatever account the caller names" interfaces (the matrix item closed 2026-08-21). Dr Inventory / Cr GRNI needs **no GL change at all**: IM names GRNI as the contra account. The GL work is the match side and the supporting pieces above.

## 2. Plan / SRS (P): numbered requirements and the answers to POP's three GL questions

### 2.1 Answers to POP's questions (Q4, Q5, Q6)

| # | Question | GL's answer | State |
|---|---|---|---|
| Q4 | Per-line debit account (or `stock` flag) on `record-obligation`, or two calls? | **Per-line debit account**, optional, on each purchase line. One call, one journal entry, atomic. Not a `stock` flag: GL stays generic and never learns what "stock" means; it is told which account to debit. Two calls are refused as a design: a failure between them leaves half an obligation, which is the same defect as seam A in another form. | Proposed (GL) |
| Q5 | GRNI account in the chart template, and a backfill rule? | **Yes: `2050 Goods Received Not Invoiced`, LIABILITY, CURRENT**, seeded in every business template (not Individual). Existing Companies get it from the existing `POST /companies/{id}/standard-accounts` (it already adds missing template codes and reports type conflicts); **no migration, no automatic backfill**: an owner or the onboarding step runs the route, as was done for the VAT account. A PO receipt in IM is refused with a clear error if the Company has no GRNI account (POP's I2), so a missing account is loud, never a silent fall back to AP. | Proposed (GL) |
| Q6 | Where does the difference between receipt cost and invoice go, and what tolerance? | **Purchase price variance (PPV) account `5020`, EXPENSE** (cost-of-sales family, seeded in business templates). GL posts the variance explicitly and **does not decide a tolerance**: POP holds the per-Company match tolerance and refuses the match (MISMATCHED) when outside it; inside it POP sends the cleared amount and GL posts the difference to PPV. The IAS 2 alternative (adjust inventory cost while stock is on hand, expense only the part already sold) is more correct but needs IM's on-hand view at match time; recorded as decision **D-G3** for Femi, default PPV expense (the IFRS matrix does not specify a variance account; its GRNI rows are A.2.2/C.1.2). | **D-G3 for Femi** |

### 2.2 Requirements

**Accounts**
- **FR-GR01 (M)** Every business chart template seeds `2050 Goods Received Not Invoiced` (LIABILITY, CURRENT, a normal-credit account) and `5020 Purchase Price Variance` (EXPENSE, classification as the cost-of-sales family so the trading P&L groups it). Individual charts do not.
- **FR-GR02 (M)** Code `2050` is added to `ModuleOwnedAccounts` with token `INVENTORY`, so the cash book refuses it as a counter-account ("use Stock"). `5020` is not module-owned.
- **FR-GR03 (M)** `POST /companies/{id}/standard-accounts` adds both to an older Company without any change to the use case (it iterates the template). A Company that already has a different-type account at `2050` or `5020` gets the existing **conflict** report and nothing is changed.
- **FR-GR04 (M)** GRNI and PPV are found **by code and type** (`2050` LIABILITY, `5020` EXPENSE), never by name.

**Finding the accounts (strict-decoder safe)**
- **FR-GR10 (M)** A **new** read route `GET /companies/{companyId}/grni-account` returns `{ "grniAccountId": "...", "priceVarianceAccountId": "..." }`. Both ids are required fields, always present. If the Company has no `2050`, the route answers **404 `grni_account_not_found`**; if it has no `5020`, **404 `price_variance_account_not_found`**. It never returns null ids.
- **FR-GR11 (M)** It goes through the full sequence every Company route uses (`resolveTenantForCompany`, `verifyClaimedTenant`, `authorizeTenantForRead`) and is added to the **pop and im** G3 allow-lists, with the allow-list inventory test updated in the same change.
- **FR-GR12 (M)** The existing `purchase-posting-context` and `inventory-posting-context` responses are **not changed**. Reason, verified: SOP, POP, IM and HR decode GL responses strictly (Femi's rule: no `ignoreUnknownKeys` on financial payloads), so any new key, even nullable, breaks every consumer that has not declared it first; POP's draft "GL ships the new fields first" is backwards for strict decoders. A new route has no ordering coupling: nothing calls it until a consumer is ready.

**`record-obligation`**
- **FR-GR20 (M)** Each `PurchaseLineDto` gains an optional `debitAccountId`. Absent: the line debits the request-level `expenseOrAssetAccountId` exactly as today (so an unchanged POP, SOP-style caller or old request behaves identically). GL decodes its **own** requests, so adding optional fields is safe for old callers.
- **FR-GR21 (M)** The entry groups debits by account: one journal line per distinct debit account (sum of its lines' net), VAT debits unchanged, one credit to AP control for the gross total tagged with the supplier. One call = one entry = atomic.
- **FR-GR22 (M)** Every `debitAccountId` must belong to the Company (else 404 `expense_or_asset_account_not_found`, naming the id, never confirming another Company's account) and must not be the AP control, the VAT control, or a cash/bank-kind account (400 `debit_account_not_allowed`). The GRNI account (`2050`) is allowed; that is its purpose.
- **FR-GR23 (M)** Optional per-line `clearedAmount` (a stock line only, meaning "the amount IM received into GRNI for this line"). When present, GL debits GRNI `clearedAmount`, and the difference to the invoiced net goes to PPV: invoiced greater than cleared is a **Dr PPV** (unfavourable); invoiced less than cleared is a **Cr PPV** (favourable). The entry still balances against AP (gross of the invoiced amount). `clearedAmount` is only valid on a line whose `debitAccountId` is the GRNI account (400 `cleared_amount_requires_grni_debit`) and must be positive; the PPV account is resolved by GL itself (no id from the caller, one less thing to get wrong), and its absence is a 409 `price_variance_account_not_configured` that leaves nothing behind.
- **FR-GR24 (S)** The GRNI debit line carries the supplier dimension (`VENDOR`) so GRNI can later be viewed by supplier; the Inventory line IM posts already carries `ITEM`. Matching a particular receipt to a particular match relies on the PO number in both entries' descriptions until Q-G6 is answered.

**Receipt side (IM)**
- **FR-GR30 (M)** **No GL change** for Dr Inventory / Cr GRNI: IM sends `contraAccountId` = GRNI from FR-GR10. Same for a return to supplier **before** the match (Dr GRNI / Cr Inventory, POP's I8, via `record-issue` with GRNI as contra) and after the match (Dr AP control / Cr Inventory, as today). Verified: the contra account in `record-receipt`/`record-issue` is caller-named and only checked to belong to the Company.
- **FR-GR31 (M)** GL does **not** police "a PO receipt must use GRNI". That rule is IM's (I2); GL refusing a contra by meaning would make GL know about purchase orders, and it would break the legitimate non-PO receipts (opening stock, adjustments, I3).

**Idempotency and retry (seam H, GL half)**
- **FR-GR40 (M)** **Done, 7298fe5 (awaiting CM release):** `respondIdempotently` stores only 2xx. A refusal does not spend the key, so POP can fix the cause and send the same key and body again; a key reused with a different body after a success is still 422.
- **FR-GR41 (M)** Retry safety for the two money routes is tested end to end: with a key, a lost reply replays the original entry id and does not post twice; a refusal (for example `period_not_open`) followed by the Period being opened and the same key posts exactly once.
- **FR-GR42 (S)** The remaining gap is the **simultaneous duplicate** (two requests with the same key both execute, the documented narrow race). Design note first (claim by entry id, as the cash book does, versus a pending row), then CM's go before any code. Until then POP's match must not retry concurrently; sequential retry is safe (FR-GR41).
- **FR-GR43 (M)** GL gives `record-obligation` and `record-payment` no new key rules. The caller chooses the key (POP: `po-match:{purchaseOrderId}`, `po-pay:{purchaseOrderId}`); GL scopes it by tenant and endpoint, as today.

**Compatibility and access**
- **FR-GR50 (M)** Additive only: no existing route, field, status code or response shape changes. Old POP, IM and WEB keep working untouched until they choose to adopt.
- **FR-GR51 (M)** Isolation (T15): every new or changed route resolves the Tenant from the Company and verifies the claim; a service login of another service gets 403 from the allow-list; a person of another Tenant gets 403. Tests follow the T15 suite pattern.
- **FR-GR52 (M)** No change to RBAC (frozen until the SPUTO RBAC work lands): the new read route reuses `authorizeTenantForRead`, the posting changes reuse `authorizeTenantForWrite`.

### 2.3 Non-functional
- The match must remain **one entry** whatever the mix of lines (atomic), and **balanced** to the cent for any combination of VAT categories, stock and non-stock lines, and variance in either direction (property-style tests).
- No new table and no migration is needed for the posting (a chart-template change is code); the GRNI and PPV accounts for existing Companies arrive through the existing route.

### 2.4 Decisions needed (for Femi)

| # | Decision | GL's default |
|---|---|---|
| D-G1 | Per-line `debitAccountId` on `record-obligation` (one atomic call) rather than two calls. | Yes (FR-GR20) |
| D-G2 | GRNI is `2050`, PPV is `5020`; found by code and type; older Companies add them by running standard-accounts (no automatic backfill). | Yes |
| D-G3 | Price variance goes to a PPV **expense** account, versus adjusting inventory cost (IAS 2) while stock is on hand. | PPV expense now; IAS 2 adjustment later if Femi wants it (needs IM's on-hand quantity at match time) |
| D-G4 | A new read route for the two ids instead of new keys in the existing posting contexts (strict decoders). | Yes (FR-GR12) |
| D-G5 | A Company with no `2050` has its PO receipt **refused** (never silently posted to AP). IM enforces; GL provides the 404. | Yes (agrees with POP's I2) |

### 2.5 Existing data (said plainly)
Test and pre-live data already holds seam A double counts (receipts credited to AP, then matches crediting AP again) and, in places, raw typed ids in descriptions. GL cannot repair it and does not try (standing rule: production data is legacy test data until the live switch). After this ships, new purchases are correct; old ones stay as they were. If Femi wants a one-off list of affected Companies and orders, it is a read-only query for CM, not a build.

## 3. Use cases (U)

**UC-GR1: Stock goods are received before the invoice (IM, no GL change).**
IM obtains `grniAccountId` from `GET /companies/{id}/grni-account`, then posts `record-receipt` with the PO number as the reference and the GRNI account as contra. Result: Dr Inventory, Cr GRNI at IM's cost. *Alternate:* no GRNI account (404): IM refuses the receipt and tells the person to add the standard accounts. *Alternate:* Period not open: 409 `period_not_open`, nothing posted, the same key can be sent again after the Period is opened.

**UC-GR2: The invoice is matched, mixed lines (POP calls GL).**
An order has a stock line (net 45,000), a service line (net 2,000) and an unlinked goods line (net 500), all at standard VAT. POP calls `record-obligation` once with `debitAccountId` = GRNI on the stock line and no `debitAccountId` on the others (they take the request-level expense/asset account). Result: Dr GRNI 45,000, Dr expense/asset 2,500, Dr input VAT, Cr AP gross, tagged with the supplier. GRNI after the match: zero for that order.

**UC-GR3: The invoice differs from the receipt (price variance).**
Received at 45,000, invoiced at 45,900 (inside POP's tolerance). POP sends the stock line with net 45,900, `debitAccountId` = GRNI and `clearedAmount` 45,000. Result: Dr GRNI 45,000, Dr PPV 900, Dr input VAT on 45,900, Cr AP gross. *Alternate:* invoiced at 44,500: Cr PPV 500. *Alternate:* outside tolerance: POP refuses (MISMATCHED) and calls nothing. *Alternate:* no PPV account: 409, nothing posted.

**UC-GR4: A retry after a failure (seam H).**
POP sends `po-match:PO-000123`. GL is unreachable or answers 503 or 4xx: nothing is stored under that key and POP saved nothing (POP posts first). The cause is fixed and POP sends the same key and body: the entry posts once. If the first call succeeded but the reply was lost: the retry replays the stored response with the same journal entry id.

**UC-GR5: A return to supplier before the invoice (IM, no GL change).**
IM posts `record-issue` with GRNI as contra: Dr GRNI, Cr Inventory. After the match, the contra is AP control as today.

**UC-GR6: An existing Company has no GRNI account.**
The owner (or onboarding) runs standard-accounts: `2050` and `5020` are added; a Company that already uses code `2050` for something else is reported as a conflict and left alone, and its PO receipts stay refused until a person resolves it.

**UC-GR7: A person tries to record a payment straight into GRNI in a cash book.**
Refused: the counter-account is module-owned (`use_instead: INVENTORY`), same as Inventory 1300.

## 4. Tasks (T)

| # | Task | Size | Notes |
|---|---|---|---|
| G1 | `respondIdempotently` stores only 2xx (**done**, branch `gl/idempotency-store-only-success`, 7298fe5) | done | awaiting CM release |
| G2 | Chart template: `2050` GRNI and `5020` PPV in the business templates, by-code constants, template tests; `ModuleOwnedAccounts` adds `2050` (token INVENTORY); standard-accounts test shows an older Company gets both and a type conflict is reported | 0.5 d | red tests first |
| G3 | New `GET /companies/{companyId}/grni-account` (use case + route + DTO + 404 codes), added to the pop and im allow-lists, allow-list inventory test updated, T15 isolation tests (other Tenant 403, other service 403) | 1 d | |
| G4 | `record-obligation`: per-line optional `debitAccountId`, grouping into one entry, account/ownership/type validation, 404/400 codes; old requests unchanged (regression test with the existing fixtures) | 1 d | |
| G5 | `clearedAmount` and the PPV leg: Dr/Cr by sign, resolve `5020` inside the use case, 409 when missing; balance property tests across VAT categories and variance directions | 1 d | |
| G6 | Retry tests on the money routes (lost reply replays; refusal then fix posts once; different body 422) for `record-obligation` and `record-payment`, including the rollback of nothing-left-behind on a 409 | 0.5 d | |
| G7 | Docs and handoff: update `docs/GL_Playbook_Draft.md` (operator sheet), the allow-list note for POP and IM, and tell POP, IM and WEB the exact response and error codes before anything is enforced | 0.25 d | |
| G8 | Claim-first idempotency design note (FR-GR42), then CM's go | design 0.5 d, build 2 d | separate, item 9 of the order list |

GL total: about **3.5 to 4.5 days** of build after approval (G2 to G7), plus G8. POP's side is about 5 to 7 days and IM's side is IM's own estimate (seam H in POP is the first item and does not depend on GL's new fields).

## 5. Order (O): dependencies, foundations first

1. **Foundation, done:** G1 (a refusal does not spend the key). It must be released before POP's seam H (post-to-GL-first with keys) is useful, because without it POP's "fix the cause and retry" would replay the old refusal.
2. **Foundation, design:** G8 (claim-first idempotency) before any feature that depends on the simultaneous-duplicate case being closed. The match and payment are safe against a **sequential** retry from G1 alone, so G8 does not block the rest; it is the last gate before concurrent callers (for example a WEB double click racing a POP retry).
3. **Approval:** Femi approves this note (D-G1 to D-G5).
4. **GL, in this order:** G2 (accounts) then G3 (read route, so consumers have something to read) then G4 (per-line debit) then G5 (variance) then G6, G7. G3 and G4 are independent of each other and may be built in either order; both come before any consumer change.
5. **Consumers, after GL is deployed (each is that service's own work):**
   - POP: seam H first (already can start, GL-independent); then declare nothing new in the existing contexts (the new route is a new call), call `grni-account`, route lines by its posting plan, send `debitAccountId` and `clearedAmount` (about 1.5 to 2 d).
   - IM: read `grni-account`, make GRNI the contra for PO receipts, refuse without it, accept GRNI as an issue contra (I1, I2, I8).
   - WEB: no screen change is required for GL's part; any screen that lets a person pick a purchase debit account should not offer 2050 (module-owned list).
6. **Enforcement:** none is needed; the new behaviour is opt-in per caller, so there is no log-first stage for this change. (The G3 service allow-list is already enforcing; the new route must be on it before the first call, which is why G3 includes it.)
7. **Cutover:** receipts and matches already posted keep their old accounts (I9, no back-posting). New receipts use GRNI after IM deploys; new matches use per-line debits after POP deploys. A purchase received before IM deploys and matched after POP deploys will have credited AP at receipt and then debited GRNI at match, leaving a **debit balance in GRNI** for that order: acceptable for test data and listed here so nobody reads it as a bug; for live data the deploy order is IM first and POP second, and a short freeze on matching orders received before the cutover.

## 6. Open questions (not blocking approval)

- **Q-G6 (GRNI clearing view):** a report of GRNI by supplier and PO (what is received and not yet invoiced) needs a stable reference on both entries. The PO number in descriptions is not queryable. A `reference` field on journal entries, or a PO dimension, is a separate small design; not needed for the posting to be correct.
- **Q-G7 (GRNI debit balance):** an invoice matched with no prior receipt on a stock line (POP's per-line rule says a line with an item is stock) leaves a debit in GRNI. That is a POP and IM question (should the match refuse a stock line with no received quantity?), noted here because GL will not refuse it.
- **Q-G8 (GL entry count):** the match is one entry in GL however many lines; IM's receipt is one entry per item line. Matching many receipts to one invoice is supported by amounts alone (GRNI nets to zero), not by linkage.

## 7. What this does not change

The cash and bank books, the VAT, tax, IAS 21 and Periods designs are untouched. No Flyway migration is introduced. The RBAC freeze and the T15 enforcement switches (G3 service allow-list already on; the T14 and settlement-account policies still log-first) are unaffected by this work.
