# Purchase receipt and match posting (the GRNI seam): POP's half

**From:** Purchase Order Processing (POP) session. **Date:** 2026-10-10. **Status:** DRAFT for IM and GL to add their halves. Design only, no code. **Why now:** Femi's "heartbeat" paradigm (SOP, IM and POP must work seamlessly together), and CM's finding that seam A is real in the code. **Written against:** POP master `52d01cd` (POP :36), GL `purchase-posting-context`, `docs/IFRS_GL_Posting_Matrix.md` (A.2.2, C.1.2).

## 1. What POP does today (facts from the code)

**The purchase cycle, as POP drives it:**

1. Create and send an order. Nothing posts.
2. `receive-line`: POP records a received quantity on the order. **It makes no call to IM and no call to GL.** Whoever receives the stock calls IM's own goods-receipt route separately.
3. `match` (three-way match): POP records MATCHED, then calls GL `POST /purchasing/record-obligation`, then saves a `VendorInvoice`.
4. `pay`: POP calls GL `POST /purchasing/record-payment`, then closes the order and settles the invoice.

**What the match posts.** One call, one debit account for the whole order:
- Debit: `expenseOrAssetAccountId`, which POP takes from GL's `purchase-posting-context`. GL fills it with **the Company's lowest-coded EXPENSE-type account** (`ComputePurchasePostingContextUseCase`: `accounts.filter { type == EXPENSE }.minByOrNull { code }`). It is the same account for goods, services and assets.
- Credit: AP control (code 2000) for the invoice total, and the VAT control account for the VAT part. VAT is computed from each line's `vatCategory`.
- Lines are sent to GL as `PurchaseLine(netAmount, vatCategory)`, so GL sees no item, no account, and no goods/service distinction per line.

**What POP knows per order line** (available today, not yet used for posting): `itemType` (GOODS or SERVICE), `itemId` (the IM item; **optional**, often absent), quantity, unit price, `vatCategory`. A GOODS line with no `itemId` never reaches IM.

**Ordering and safety.** The match saves the order as MATCHED **before** it calls GL. If GL refuses or fails, the order stays MATCHED with no journal entry and no invoice, and cannot be re-matched (MATCHED can only go to CLOSED). Payment is the other way round (GL first, then save), so a failed save after a successful GL call could post twice on retry. **POP sends no Idempotency-Key to GL on either call.** (Seam H below; not part of this note's posting design, but it must be fixed together with it, section 5.)

**IM's side, as CM read it.** `RecordGoodsReceipt` posts Dr Inventory / Cr contra, and `ItemRoutes.kt:228` defaults the contra to the AP control account when the caller gives none. POP's gateway has a `recordGoodsReceipt` method, but nothing in POP calls it; the receipt is made by another caller (WEB today).

## 2. The seam: what posts today for one stock purchase

A purchase of 100 bags at 450 (net 45,000, standard VAT), item linked to an IM item, received then matched:

| Step | Who | Debit | Credit |
|---|---|---|---|
| Goods received in IM | IM | Inventory 45,000 | **AP control 45,000** (default contra) |
| Three-way match | POP | **Lowest-coded expense account** 45,000, plus input VAT | **AP control 45,000** plus VAT payable |

Result for the same purchase: AP credited twice (90,000 owed for a 45,000 purchase), inventory capitalized once and the same cost also expensed once. For a SERVICE or an order with no item link, only POP's step runs and it is correct (Dr expense / Cr AP + VAT). If the person making the IM receipt passes an explicit contra, the result changes, which makes today's behaviour depend on an optional field.

## 3. Target posting (agrees with the IFRS matrix and CM's proposal)

| Event | Lines with an IM item (stock) | Lines without one (services, assets, unlinked goods) |
|---|---|---|
| Goods received (IM) | Dr Inventory / **Cr GRNI** (goods received not invoiced), at the cost IM records | nothing (no IM receipt exists) |
| Invoice matched (POP) | **Dr GRNI** / Cr AP; VAT Dr input VAT at match | Dr expense or asset / Cr AP; VAT as today |

Principles:
- GRNI is the only account both systems touch. IM puts a liability in, POP's match takes it out against AP. The invoice, not the receipt, recognizes AP and VAT (the matrix's rule, and POP's own earlier decision: AP recognition at match, not at send).
- The debit at match is **per line**, chosen by whether the line is stock. One order can contain both kinds.
- Anything that never went through IM never touches GRNI, so there is nothing to clear.

## 4. What POP would change (POP half)

1. **Per-line debit account at match.** Today one `expenseOrAssetAccountId` covers the whole order. POP needs to tell GL, per line, whether to debit GRNI (line has an `itemId`) or the expense/asset account. Two shapes; GL decides which it prefers:
   - (a) GL's `record-obligation` accepts a debit account (or a flag `stock = true`) on each `PurchaseLine`. One atomic call. POP's preference.
   - (b) POP splits the order into two calls, one for stock lines and one for the rest. Not atomic: a failure between the two leaves half an obligation. POP does not want this.
2. **GRNI account in the posting context.** `purchase-posting-context` returns `grniAccountId`, and the Company's chart of accounts template carries a GRNI liability account. This is GL's half; POP only reads the id.
3. **Which lines are "stock".** POP rule: a line is stock when it has an `itemId`. A GOODS line with no `itemId` is treated as an expense/asset line (no IM receipt can exist for it), so there is nothing in GRNI to clear. Open question 1 asks whether that is acceptable or whether unlinked goods should be refused at match.
4. **Link the receipt (T10).** For the match to clear exactly what IM received, POP and IM need the same receipt reference. POP's own receive-line today records a quantity only. Two options for IM and POP to choose between:
   - (a) POP calls IM's receipt as part of `receive-line` (one request records both), with an idempotency key per receipt and a receipt identity.
   - (b) The receiver keeps calling IM separately, passing the PO number (PO-000123) as the reference, and POP's match checks IM's received quantity through a read call.
   Option (a) fixes the "POP says received, IM has no stock" drift at the same time; it needs a receipt record in POP (today a receipt is only a running total) and costs about 2 to 3 days.
5. **Receipt cost.** IM must value the receipt at something. POP proposes the PO line's unit price, passed with the receipt, and the match clears GRNI at the invoiced amount. The difference is price variance (question 3).
6. **Order of operations at match and idempotency (seam H).** Change the match to post to GL first with an idempotency key (for example `po-match:{purchaseOrderId}`), then record MATCHED and the invoice only when GL answers success. A failure then leaves nothing saved and a retry works; a lost reply replays instead of double posting. The same for payment (`po-pay:{purchaseOrderId}`). This is T7 and about 1.5 to 2 days; it should ship with or before item 1.
7. **Wire shape.** Items 1 and 2 add fields to GL's `record-obligation` and `purchase-posting-context`; POP's and IM's DTOs for those are strict, so GL ships the new fields first and POP declares them before using them (consumers-first, as agreed for `/me`).

## 5. Order of work

1. **Now, regardless of GRNI:** seam H (post to GL first, with idempotency keys on match and pay). POP only. 1.5 to 2 days. It prevents a stuck order on any GL refusal, including a blocked call under the allow-list.
2. GL: GRNI account in the chart template, `grniAccountId` in the posting context, per-line debit account or stock flag on `record-obligation`. IM: PO receipts credit GRNI (the contra becomes GRNI whenever the receipt is against a purchase order), and a receipt reference that is the PO number.
3. POP: per-line debit at match (item 4.1), after GL's fields exist. 1.5 to 2 days.
4. POP and IM: the receipt link (T10), 2 to 3 days, can follow.
5. A one-off check that the double posting is real in production data: until step 3 ships, **a stock purchase that is both received in IM and matched in POP double counts**, and test data should not be read as correct.

## 6. Tests POP would add

- **Posting matrix test (POP side, fake GL):** for an order of one stock line, one service line and one unlinked goods line, the obligation request carries exactly one GRNI debit for the stock line and expense/asset debits for the others, and totals equal the invoice.
- **No double count end to end:** with the real IM and GL stack in the combined suite, receive then match one stock line and assert GL's AP balance equals the invoice once, GRNI is zero after match, inventory equals the received cost.
- **GL refusal leaves nothing saved:** record-obligation answers 4xx/5xx, the order is still FULLY_RECEIVED with no invoice, and the same match succeeds on retry; a lost reply replays through the idempotency key.
- **Partial deliveries:** two receipts, one match, GRNI clears for the received quantity only, and an over-invoiced quantity is MISMATCHED, not posted.
- **Isolation:** the GRNI account and every GL call carry the Company and Tenant of the request (the T15 suite's pattern).

## 7. Questions for IM and GL

For **IM:**
1. When a receipt is against a purchase order, may IM make GRNI the default contra and take the account from GL's posting context rather than from the caller?
2. Will IM accept the PO number as the receipt reference, and expose a read for received quantity per PO line so POP's match can compare?
3. What cost does IM record on a receipt when the caller supplies none, and is a variance against the invoice posted by IM or left to POP's match?

For **GL:**
4. Per-line debit account (or `stock` flag) on `record-obligation`, or two calls? (POP prefers per-line.)
5. A GRNI account in the Company chart template, and a backfill rule for Companies that already exist?
6. Price variance: where does a difference between the receipt cost and the invoice go (a variance account, or adjusted into inventory under the matrix's A.2 rules), and what tolerance applies? POP already has a per-Company match tolerance percentage.

For **POP/Femi:**
7. A GOODS line with no item link: treat as expense/asset (today's behaviour and what this note assumes), or refuse it at match so stock cannot be bought outside IM?

## 8. POP's estimate

| Piece | Size |
|---|---|
| Seam H, post-GL-first with idempotency keys (T7) | 1.5 to 2 days |
| Per-line debit at match, GRNI from context, tests | 1.5 to 2 days (after GL's fields) |
| Receipt link with IM (T10) | 2 to 3 days |
| Total POP half | about 5 to 7 days, in that order |

## 9. What this does not cover

Returns outwards posting (dispatch already issues stock through IM against the AP control account; with GRNI in place its contra should be revisited by IM and POP together), partial payments (T8), and multi-currency receipts. All three are listed so nobody assumes they are settled.

## 10. IM's half, proposed by POP for IM to approve or amend (added 2026-10-11)

IM's session has not been reachable, so POP proposes what IM's side must do, from reading the contract it depends on. Nothing here is built, and IM owns every line of it.

**What IM's receipt posts instead of crediting Accounts Payable: GRNI.**

| # | Proposal | Why |
|---|---|---|
| I1 | A goods receipt that references a purchase order posts **Dr Inventory / Cr GRNI**. Today the contra defaults to the AP control account (`ItemRoutes.kt:228`: `request.contraAccountId ?: context.apControlAccountId`). | The invoice, not the receipt, creates the payable. Receiving goods you have not been billed for is an accrual (GRNI), cleared by POP's match. |
| I2 | The GRNI account comes from GL's posting context (`grniAccountId`, GL's half), never from the caller's guess. If a Company has no GRNI account, a PO receipt is **refused with a clear error**, not silently posted to AP. | A silent fallback to AP would recreate the double recognition. |
| I3 | Receipts that are NOT against a purchase order (opening stock, adjustments, stock-count corrections) keep their current contra. | They are not matched by POP, so there is no invoice to clear GRNI. |
| I4 | The receipt carries the **PO number** (`PO-000123`, live since 2026-10-08) as its `purchaseOrderReference`, plus the line index, so receipts and POP's order lines can be paired. | One human reference both systems show; no id guessing. |
| I5 | The receipt cost is the PO line's unit price times the quantity received, supplied by the caller (POP, or WEB until POP calls IM itself). The difference between this cost and the invoice is a price variance, settled in the GL half (question 6). | IM should not invent a cost; the order is the agreed price. |
| I6 | IM exposes a read for POP's match: received quantity (and cost) **per PO reference and line**. | The match then compares against what IM actually holds, not only POP's own running total (seam B). |
| I7 | A receipt idempotency key, as IM has for issues (key per receipt, the same body replays, a different body answers 422). | Today a lost reply on a receipt can post stock twice. |
| I8 | **Return to supplier before the invoice** (dispatch before the match): Dr GRNI / Cr Inventory. **After the match:** Dr AP control / Cr Inventory (as today). POP already knows the order's status and passes the contra; IM only needs to accept GRNI as a valid contra on an issue. | A returned good that was never billed should reduce the accrual, not create a debit in AP. |
| I9 | **Cutover.** Receipts already posted against AP stay as they are (test data pre-live, per the standing rule). The new contra applies to receipts recorded after the contract is live. No back-posting. | Avoids rewriting history; pre-live data is disposable. |

**What POP will do on its side** once IM and GL have merged (section 4): route each line by the posting plan POP prepared (stock line, `itemType` GOODS with an `itemId`, goes to GRNI; the rest to expense or asset), send the PO number with each receipt it takes over (T10), and pass GRNI as the contra for a pre-match return.

**IM, please answer:** approve, amend or reject I1 to I9; in particular I2 (refuse without a GRNI account), I5 (who supplies the cost) and I8 (GRNI as a valid contra on an issue). Until you do, POP changes nothing that touches IM.

*Where the work that does not need an answer stands (2026-10-11):* POP has the item-link rule as a per-line posting plan (`PurchaseOrder.postingPlan()`, not yet used by the match), and a test that reproduces the double recognition end to end against models of IM's receipt and GL's obligation, with the target contract shown to be fully driven by that plan. What the match posts is unchanged.

