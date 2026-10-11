# Purchase receipt and match posting (the GRNI seam): IM's half (SPUTO)

**From:** Inventory Management (IM) session. **Date:** 2026-10-11. **Status:** DRAFT for Femi's approval as a Playbook part. Docs only: **no IM code is written until Femi approves** (CM, 2026-10-11). **Written against:** IM master `cf97150` (task definition `:32`), POP's half `docs/POP_IM_GL_Purchase_Posting_Design_POP_Half.md` (sections 1 to 10, including POP's proposed IM half I1 to I9) and GL's half `docs/POP_IM_GL_Purchase_Posting_Design_GL_Half.md` (FR-GR01 to FR-GR52). Everything marked "checked" was read in IM's code today.

Form: Femi's SPUTO (Scope, Plan/SRS, Use cases, Tasks, Order), so POP, GL and IM have one Playbook to build against.

---

## 1. Scope (S)

**What IM owns in the fix.** IM does not decide which order lines are stock (POP's `itemId` rule), does not compute VAT, and does not post a price variance (GL does). IM owns only:
1. **What a purchase-order goods receipt posts**: `Dr Inventory / Cr GRNI` instead of `Dr Inventory / Cr Accounts Payable`.
2. **What a receipt remembers**, so POP's match can clear exactly what was received (cost, line, and which account it credited).
3. **Making the receipt safe to retry and atomic**, because it is now the first half of a two-system money flow.
4. The few places where IM's *other* postings (issues, returns, opening stock, count adjustments) are affected or deliberately not.

**Checked facts that shape the design.**
- Today the receive route resolves the contra as `request.contraAccountId ?: context.apControlAccountId` (`ItemRoutes.kt`, the `/items/{id}/receive` handler). That default is the whole of seam A on IM's side.
- `purchaseOrderReference` is a **required free-text field on every receipt**, so IM cannot tell a "PO receipt" from any other by that field being present. The rule therefore has to be: *no explicit contra means a purchase-order receipt means GRNI*; an explicit contra is always respected (as now).
- `RecordGoodsReceiptUseCase` calls GL **first**, then saves the Item, the confirmation and the bin balance as **three separate writes with no unit of work and no idempotency key**. The issue side already has both (built 2026-10-07); the receipt side was parked. Today a failed save after a successful GL call leaves GL ahead of IM, and a retry posts stock twice.
- Receipt cost is **required and caller-supplied** (`costReceivedAmount`); IM computes only the running weighted average from it. IM never invents a cost.
- Opening stock already posts `Dr Inventory / Cr Suspense` through its own use case. Count adjustments post with `contraAccountId ?: item.cogsExpenseAccountId`. Goods issue takes a caller-named contra, defaulting to the Item's COGS account. None of these touches AP today.
- IM's GL client decodes the posting context strictly (read-only, fine) and, after the 2026-10-11 fix (`d993172`, in CM's queue), the two posting responses tolerantly.

**Out of scope here.** POP's per-line match and the receipt link at `receive-line` (POP), the accounts and the variance posting (GL), returns inwards (needs a generalised receipt, already scoped in `docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`), multi-currency receipts (IAS 21 design), partial payments.

---

## 2. Plan / requirements (P)

### 2.1 Answers to POP's questions and proposals

| # | POP's question or proposal | IM's answer |
|---|---|---|
| Q1 | May IM default the contra to GRNI for a PO receipt, taking the account from GL rather than the caller? | **Yes.** Only the *default* changes: no `contraAccountId` in the request now means GRNI. An explicit contra is used as given. The account comes from GL's new `GET /companies/{companyId}/grni-account` (GL's FR-GR10), not from the caller. |
| Q2 | Accept the PO number as the receipt reference and expose received quantity per PO line? | **Yes.** The PO number is already the `purchaseOrderReference` field. IM adds an optional `purchaseOrderLineIndex` and a read route (section 3). |
| Q3 | What cost does IM record when the caller supplies none, and who posts the variance? | **None is supplied by IM.** `costReceivedAmount` is required today and stays required: the caller (POP, or WEB until POP takes over) states the PO price. IM posts **no** variance; GL posts it at match from POP's `clearedAmount` (GL FR-GR23). |
| I1 | PO receipt posts Dr Inventory / Cr GRNI | **Approved, refined** as in Q1: default only. |
| I2 | GRNI from GL; refuse without it, never fall back to AP | **Approved.** IM answers `409 grni_account_not_configured` (detail: "run standard accounts for this Company") and posts and saves nothing. This is a behaviour change for any Company without the GRNI account (see risk 6). |
| I3 | Non-PO receipts keep their contra | **Approved.** Opening stock (Suspense), count adjustments (COGS/explicit), explicit-contra receipts: unchanged. |
| I4 | Receipt carries the PO number and line index | **Approved.** `purchaseOrderReference` (existing) plus optional `purchaseOrderLineIndex` (new). |
| I5 | Cost = PO line price times quantity, caller-supplied; variance settled in GL | **Approved** (Q3). |
| I6 | A read for received quantity (and cost) per PO and line | **Approved, extended:** each receipt also reports which account kind it credited (`contraKind`), which solves the cutover problem without a freeze (section 3). |
| I7 | Receipt idempotency key | **Approved and promoted to a foundation task** (A0): it must exist before the receipt posts to a liability account POP will clear. |
| I8 | Return before the invoice: Dr GRNI / Cr Inventory; after: Dr AP / Cr Inventory | **No IM change needed.** `record-issue` already takes a caller-named contra; POP passes GRNI or AP. IM adds a pinning test. One real caveat in risk 2. |
| I9 | Cutover: no back-posting | **Approved**, with `contraKind` so POP clears GRNI only against receipts that credited it. |

### 2.2 Requirements

| # | Requirement |
|---|---|
| R1 | A receipt with no `contraAccountId` credits the Company's GRNI account (from GL's `grni-account` route); a receipt with one uses it unchanged. |
| R2 | If GL answers 404 for the GRNI account, IM answers `409 grni_account_not_configured` and changes nothing: no GL call to post, no Item, confirmation or balance written. IM never falls back to the AP control account. |
| R3 | A receipt confirmation also stores: `company_id`, `cost_amount` (the committed cost of the receipt, not the unit cost), `currency`, `journal_entry_id`, `purchase_order_line_index` (nullable) and `contra_kind` (`GRNI` or `OTHER`). |
| R4 | `GET /companies/{companyId}/goods-receipts?purchaseOrderReference=…` returns the confirmations for one PO number (read access), each with quantity, cost, date, line index, `contraKind` and `journalEntryId`. Company-scoped like every IM route. |
| R5 | A receipt accepts an optional `Idempotency-Key` with the same rules as the issue: same key and same request replays the original answer without changing anything; same key with a different request is `422`; two simultaneous identical requests execute once; a definite GL refusal frees the key. |
| R6 | A receipt's Item, confirmation and bin-balance writes happen in one unit of work, as the issue's already do, so a failure cannot leave stock changed without its confirmation. |
| R7 | The key's scope includes the operation (receipt versus issue), so one key string can never collide across the two. |
| R8 | The goods-issue route continues to accept any caller-named contra, so a return before the invoice can credit Inventory against GRNI. A test pins it. |
| R9 | IM never chooses a cost and never posts a purchase price variance. |
| R10 | Opening stock, count adjustments and explicit-contra receipts are unchanged (I3). |
| R11 | Contract changes ship consumer-first (section 5). The new read route has no ordering coupling; the receipt's request and response shapes only gain optional fields. |
| R12 | Tenant isolation as everywhere: every new or changed route resolves the Company, checks ownership and membership, and a service token of another service is refused. |

### 2.3 Decisions needed (for Femi)

| # | Decision | IM's default |
|---|---|---|
| D-I1 | A PO receipt in a Company with no GRNI account is **refused**, never posted to AP. | Yes (agrees with POP I2 and GL D-G5). Consequence: every test Company must have the standard accounts run before it can receive stock against an order. |
| D-I2 | Receipt idempotency and atomic save come **before** the GRNI change, not after. | Yes. It is Femi's own ordering rule (foundations before money features) and the receipt becomes half of a two-system flow. |
| D-I3 | Cutover by recording `contraKind` on every receipt, instead of a freeze on matching orders received before the change. | Yes. Receipts posted before the change stay AP-credited and are reported as `OTHER`; POP then clears GRNI only for `GRNI` receipts. |

---

## 3. Wire contract (draft, nothing built)

**Receive** (`POST /companies/{companyId}/items/{id}/receive`): unchanged request, plus optional `purchaseOrderLineIndex` (integer) and an optional `Idempotency-Key` header. Response shape unchanged. New error: `409 grni_account_not_configured`.

**Read receipts** (new): `GET /companies/{companyId}/goods-receipts?purchaseOrderReference=PO-000123`

```json
{ "receipts": [ {
    "id": "…", "itemId": "…", "purchaseOrderReference": "PO-000123", "purchaseOrderLineIndex": 0,
    "quantityReceived": "100", "costAmount": "45000.00", "currency": "SLE", "date": "2026-10-11",
    "contraKind": "GRNI", "journalEntryId": "…" } ] }
```
`purchaseOrderLineIndex` and `journalEntryId` are `null` for receipts made before this change. `contraKind` is `OTHER` for any receipt that did not credit GRNI. A PO number with no receipts returns an empty list, not an error. The match is **exact on the PO number string**: a typed variation does not pair (risk 5).

**GL client** (IM to GL): a new `fetchGrniAccount(companyId)` call to `GET /companies/{companyId}/grni-account`, decoded strictly (a read with no side effect) into both ids GL always returns. IM is on GL's service allow-list for it (GL's FR-GR11). The existing posting-context responses are untouched, matching GL's FR-GR12; the change POP drafted ("GL ships new fields in the context") is not used.

---

## 4. Use cases (U)

| # | Use case |
|---|---|
| UC-IM1 | **Receive against an order, invoice not yet arrived.** WEB (or later POP) receives 100 bags at the PO price. IM posts `Dr Inventory / Cr GRNI`, stores the confirmation with the PO number, line, cost and `contraKind = GRNI`. |
| UC-IM2 | **No GRNI account.** IM answers `409 grni_account_not_configured`, nothing is posted or saved; the owner runs standard accounts and retries. |
| UC-IM3 | **Double-tap or lost reply on a receipt.** The same `Idempotency-Key` replays the first answer: one stock increase, one ledger entry. |
| UC-IM4 | **Partial deliveries.** Two receipts for one PO line each record their own cost and quantity; the read route lists both; POP clears GRNI for their sum. |
| UC-IM5 | **Receipt made before this change.** It stays credited to AP and reads back as `OTHER` with null line and journal id; POP does not debit GRNI against it. |
| UC-IM6 | **Return to supplier before the invoice.** POP calls the issue route with GRNI as contra: `Dr GRNI / Cr Inventory` at IM's cost. After the match the contra is AP, as today. |
| UC-IM7 | **Opening stock, count correction, explicit-contra receipt.** Behave exactly as today. |
| UC-IM8 | **A machine reads receipts.** POP's service token reads the list for one PO number; another Tenant's Company or another service's token is refused. |

---

## 5. Tasks (T) and order (O)

### Tasks

| # | Task | Size | Notes |
|---|---|---|---|
| A0 | **Foundation:** receipt idempotency (key, claim/complete/release, 422 on a different request, replay) and one unit of work for Item, confirmation and balance; key scoped by operation (R7). Reuses the issue's machinery and tests. | 1.5 to 2 d | Migration adds `company_id`, `idempotency_key`, `journal_entry_id` to the receipt confirmation and an `operation` column to the key table. WEB and POP then send a key (their tasks). |
| A1 | GL client `fetchGrniAccount` with a real-shape contract test copied from GL's response type. | 0.25 d | Ships only when GL's G3 route exists. |
| A2 | Default contra to GRNI, `409 grni_account_not_configured`, confirmation columns (`cost_amount`, `currency`, `purchase_order_line_index`, `contra_kind`), optional `purchaseOrderLineIndex`. Tests red first, including the refusal leaving nothing behind. | 1 d | Migration number: next free at build time, after the product-VAT migration (CM gates). |
| A3 | `GET /goods-receipts?purchaseOrderReference=` with Company scoping, service-token allow, and isolation tests. | 0.5 to 1 d | POP declares its decoder before using it. |
| A4 | Pin test that the issue route accepts GRNI as contra; operator sheet and error glossary updated. | 0.25 d | |
| A5 | **WEB:** show `grni_account_not_configured` in plain words with the fix; send an idempotency key on receive; never offer a contra account. | WEB's estimate | Held until A2 is live. |

IM total: about **3.5 to 4.5 days** (A0 to A4), plus WEB's small part.

### Order (foundations first)

1. **Now, independent of GL:** A0. It needs nothing from GL or POP and is the foundation the rest assumes.
2. GL releases its idempotency fix (G1) and builds its accounts and `grni-account` route (G2, G3). IM does A1 as soon as G3 exists.
3. GL builds G4 and G5 (per-line debit, variance). Independent of IM.
4. IM builds A2 and A3 **after GL's G2 and G3 are deployed and the test Companies have had standard accounts run**, so the first refusal is deliberate and not a surprise.
5. A4, then WEB A5.
6. POP: per-line match using A3's read route to learn what each line received (`GRNI` receipts only), then the receipt link at `receive-line` (their T10).
7. **Deploy order: GL, then IM, then POP.** IM's new default only credits GRNI once GL's account exists; POP's match debits GRNI only for receipts that credited it.

---

## 6. Risks and things nobody asked (candid)

1. **The receipt is not safe today.** It posts to GL and then saves three things separately with no key. A failure in between, or a retry after a lost reply, leaves GL and IM disagreeing or posts stock twice. A0 closes it and must come first.
2. **Returns before the invoice leave a residue in GRNI.** The receipt credits GRNI at the PO price, but IM issues returned stock at its **current weighted-average cost**, which may differ. The GRNI balance then does not net to zero by itself. Not solved here. Options for POP and GL to choose: treat the residue as price variance at match, or let a return before the invoice be issued at the receipt's own unit cost (IM would need that as an explicit override). Open question Q-IM1.
3. **GRNI debit balance when an invoice has no receipt** (GL's Q-G7). With A3, POP can see "no receipt found" for a stock line and decide whether to refuse the match. IM supplies the fact, POP decides.
4. **Pairing is by exact PO number string.** The receive form takes the reference as free text, so a typo never pairs. POP's receipt link (T10), where POP makes the IM call itself with the real PO number, removes the typing. Until then the match must treat "no receipts found" as a refusal, not a zero.
5. **No GRNI account means no receipt.** After A2 ships, every Company without `2050` cannot receive stock against an order until someone runs standard accounts. That is the intended loudness (D-I1) but it will surprise anyone who does not know; the UAT tester's Companies and any new Company need the step, and WEB must say so in plain words (A5).
6. **Existing data stays wrong.** Receipts already credited to AP, then matched, are double-counted (GL's section 2.5). Nothing here repairs them (pre-live data, standing rule).
7. **The stock-adjustment receipt path** (a positive count variance) already runs through `recordReceipt`; it keeps its COGS or explicit contra (R10). If that is ever meant to credit GRNI it is a separate decision, not part of this change.
8. **WEB's current receive form** types a contra-free request, so it will start crediting GRNI the moment A2 is live, for every Company that has the account. Intended, but it changes live behaviour, so CM deploys A2 only after GL's accounts exist (order step 4).

---

## 7. What this does not change

The issue route's own idempotency and lock, opening stock, count adjustments, valuation, FIFO and batch handling, the product VAT category (`docs/IM_Product_VAT_Category_SPUTO.md`), RBAC (frozen) and Tenant isolation rules. No change to what IM returns to POP or SOP beyond optional new fields and one new error code.
