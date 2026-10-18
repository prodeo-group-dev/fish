# Returns to a supplier: what is taken off what we owe (a short design note, POP with GL and IM, tied to seam A)

Written by the POP session, 2026-10-18. DOCS ONLY: no code until CM confirms the order. For GL and IM to correct, then CM, then Femi. Built from the code (POP master, the T-D5 credit-note route, IM's `postedAmount`) and from the seam A documents (`POP_IM_GL_Purchase_Posting_Design_GL_Half.md` and `_IM_Half.md`), not from memory.

## 1. Scope (S)

**The decision (Femi, 2026-10-18).** When goods go back to a supplier, the amount taken off what we owe is **what the supplier charged (price plus VAT)**; any difference from the stock's average cost is shown as a **cost difference**; the **input VAT is reversed**.

**The defect it fixes (a test, 2026-10-18).** Today a return's dispatch asks Inventory for a goods issue with the AP control account as its contra, valued at the item's moving-average cost. So AP falls by the stock's cost (406.28 in the test) instead of by the supplier's price plus VAT (400 + 80 = 480), AP stays 73.72 too high, and the VAT is never reversed. The return's credit note posts nothing: it is a reference only. A return of a line that has no inventory item moves nothing in AP at all.

**In scope:** the posting of a return that is dispatched AFTER the supplier invoice was matched. **Tied to seam A, not decided here:** a return dispatched BEFORE the match (then no AP exists yet; the seam A design already says Dr GRNI / Cr Inventory with the caller-named contra, and the match later clears only the net received).

**Out of scope:** returns of goods already sold (Inventory refuses them, a decision for Femi), the supplier's own printed credit note (kept as a document, section 2.4).

## 2. Plan (P)

### 2.1 The posting, worked on the test's numbers

One unit returned from an order of 2 at 400.00 net, 20% VAT, stock average cost 406.28.

| Entry | Posts | Who |
|---|---|---|
| Stock leaves | Dr **5020 Purchase Price Variance** 406.28 / Cr **Inventory** 406.28 | Inventory's goods issue, with the contra **named by POP as 5020** instead of AP |
| Debit note | Dr **2000 Accounts Payable** 480.00 / Cr **5020 Purchase Price Variance** 400.00 / Cr **Input VAT** 80.00 | GL, from POP, at the ORDER's price |
| Net on 5020 | Dr 406.28 less Cr 400.00 = **Dr 6.28**: the cost difference | shown as a cost difference in the reports |

Result: AP falls by 480.00 exactly (price plus VAT), the VAT is reversed, Inventory falls by its real cost, and the 6.28 is visible. Each entry balances alone, so no cross-service atomicity is needed: each is keyed and retryable.

For a line with NO item (a service, or goods bought off the list) there is no stock to move: the debit note credits the **line's own account** (`accountId`, else Suspense 3910) instead of 5020. Today that line moves nothing in AP; this fixes it.

### 2.2 What each service does

| Service | Change | Size |
|---|---|---|
| **GL** | (a) `record-credit-note` gains `kind RETURN` with a caller-supplied **credit account per line** (5020 for a stock line, the line's account otherwise); DISCOUNT and REBATE keep crediting 4920. The VAT is computed by GL on the net lines at the ORIGINAL purchase date's rate, as for the other kinds (Femi), and tagged input. (b) the purchase posting context also returns the Company's 5020 account id (optional; POP refuses a return dispatch of a stock line with 409 `price_variance_account_not_configured` when absent). (c) a fixture. | ~1 d (the route already exists) |
| **IM** | None to its route: the issue already takes a caller-named contra. A test pins that a return can name 5020. `postedAmount` (already built) tells POP the cost it moved. | ~0.25 d |
| **POP** | At dispatch: (1) goods issue to IM with contra 5020 and key `return-outwards:{company}:{return}` (exists); (2) debit note to GL, keyed `return-debit:{return}`, lines = returned quantity at the order's unit price (net, after any trade discount) with the order's VAT categories; (3) record the debit note as a **credit applied to the order's invoice** (the V26 mechanism) so the invoice's outstanding falls by the gross, and a return after payment leaves an unapplied supplier credit; (4) the return becomes DISPATCHED only when BOTH postings exist, with a marker for each; a retry re-sends whichever is missing under its own key. | ~2 d |
| **WEB** | The return screen shows "we owe 480.00 less, of which VAT 80.00", and the cost difference once posted. | WEB's estimate |

### 2.3 Order (consumer-first)

1. GL: the accounts (5020 already planned in seam A), the context field, `kind RETURN`, fixture.
2. POP declares the context field and the answer fields (tolerant) before GL ships.
3. IM: the pinning test; nothing else.
4. POP builds the dispatch change and the credit application of the return.
5. WEB.

Seam A decides GRNI (2050) for the before-match case and the receipt side; this note does not touch it. If seam A is built first, step 1 reuses its 5020.

### 2.4 The supplier's own credit note

The credit note a supplier sends for the goods stays a **document**: its reference and amount are recorded on the return (as today) and **compared** with what POP debited; a difference is shown, never posted twice. A supplier credit note that is NOT for returned goods (a price allowance) stays the DISCOUNT or REBATE credit note already live.

## 3. Use cases (U)

| # | Use case |
|---|---|
| UC-1 | Return 1 of 2 units after the match: AP falls by 480.00, VAT 80.00 reversed, stock falls by 406.28, cost difference 6.28 shown. |
| UC-2 | Return after the invoice was paid in full: AP goes 480.00 into a supplier credit balance (an unapplied credit), nothing is refused. |
| UC-3 | Return of a service or a line with no item: the debit note credits the line's own account; no goods issue. |
| UC-4 | Inventory is down when the return is dispatched: nothing is posted, the return stays unposted, the retry sends the same keys. |
| UC-5 | Inventory posted but GL failed: the retry posts only the debit note (its own key). |
| UC-6 | Two partial returns on one line: each posts its own debit note; the invoice's outstanding falls twice. |
| UC-7 | A return of goods already sold: Inventory refuses (409 `invalid_issue`), nothing posts. |

## 4. Tasks, estimates and open points (T/O)

Total about **GL 1 d, IM 0.25 d, POP 2 d, WEB 1 d**; POP's part builds on the credit application (V26), which is finishing now.

**Open points**
- **GL (please correct):** is extending `record-credit-note` with `kind RETURN` and a per-line credit account right, or do you prefer a separate debit-note route? POP does not mind; it needs the same answer shape (`journalEntryId`, `status`, `creditNoteTotal`, `vat`).
- **IM:** confirm no change to the issue route is needed, and that `postedAmount` is the cost moved.
- **Seam A:** if GRNI is built before this, is the before-match return `Dr 2050 / Cr Inventory` posted by Inventory alone (no GL debit note), as the IM half says?
- **Femi (only if he wants to change a default):** the cost difference is shown on the Company's Purchase Price Variance account; the reports can call it "Cost differences".
