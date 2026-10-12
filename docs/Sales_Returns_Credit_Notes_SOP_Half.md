# Sales returns and credit notes: SOP's half (SPUTO)

**From:** Sales Order Processing (SOP) session. **Date:** 2026-10-12. **Status:** DRAFT for Femi's approval as a Playbook part. Docs only: **no SOP code until Femi approves** (CM, 2026-10-11). **Answers:** GL's half (`docs/Sales_Returns_Credit_Notes_GL_Half.md`), Q-SR1 and Q-SR2. **Written against:** SOP master `f65c7b7` plus the VAT step 1 branch (line category stored, V18). IM covers the stock-value side.

Form: Femi's SPUTO (Scope, Plan/SRS, Use cases, Tasks, Order).

---

## 1. Scope (S)

**What SOP owns in a sales return:** the return request lifecycle (create, submit, approve, receive, inspect), the decision of which returned lines earn a credit note and for how much, the credit note itself and its audit, the screen contract WEB builds against, and calling GL (and IM for the stock leg) with a key that makes a retry safe.

**The defects, verified in SOP's code (2026-10-12):**

1. **The credit note is one typed amount.** `POST /api/return-requests/{id}/issue-credit-note` takes `amount`, `currency`, `periodId`, `salesReturnsAccountId`, `arControlAccountId`. SOP derives nothing: not the amount from the returned lines, not the period or accounts from GL. No person screen can call it (nobody knows an account id), which is why the sitting found no way to return goods.
2. **No VAT travels.** SOP sends GL one amount, so GL's posting cannot reverse VAT (GL half, section 1).
3. **No Idempotency-Key** is sent. The credit note is saved only after GL accepts, so a timeout after GL posted leaves a posted credit note SOP does not know about, and a retry posts a second one.
4. **Eligible quantity is typed by the caller and not cumulative.** `ReturnRequestLine.maxEligibleQuantity` is supplied in the request, never derived from the order line, and two return requests against the same order line each see the full quantity: a customer can be credited for more than was sold.
5. **Return quantities are whole numbers** (`Int`); orders now carry decimal quantities (7.5 hours). A service or measured line cannot be returned in part.
6. **Orders stored before 2026-10-11 have no line category** (V18 stores it from now on). A credit note on such an order cannot say which VAT category to reverse.
7. **A credit note has no date of supply.** SOP stores no "invoiced on" date; the order's creation date is the nearest fact.

**Out of scope here:** the stock-value leg (IM), Scrap and Repairable dispositions (still open in `docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`), cash refunds (a payment, not a return), foreign-currency credit notes, Returns Outwards (POP).

## 2. Plan / SRS (P)

### 2.1 Answers to GL's questions

**Q-SR1: where SOP gets net and VAT category per credit-note line.** From the original sale's own lines, never typed:
- a credit note line is **(order line, quantity returned)**; its **net** is the order line's unit price times the quantity returned, rounded once to the currency's minor unit; its **category** is the frozen copy stored on that order line (V18, the decision of 2026-10-11: a posted document reprints exactly as issued);
- so GL's **lines shape is right** and SOP will use it. **Do not add "gross plus one category"** to GL: it is lossy for a mixed-rate invoice and SOP can always supply the per-line net and category;
- an order whose line has **no recorded category** (stored before V18) is **refused** for a lines-shape credit note (409 `line_vat_category_not_recorded`, naming the line). It is never guessed and never given a default. Those orders are legacy test data; until GL enforces D-SR5 they can still use the single-amount shape.

**Q-SR2: the cent of rounding.** **Accept GL's computation** (VAT per category on the credit note's summed net, at the rate of the original supply date). SOP passes net and category only; SOP never passes a VAT amount, so there is one calculator (GL) and no second copy of the tax rules. A partial return can differ from the original VAT by one minor unit; the credit note shows exactly what GL posted. If an accountant later needs to-the-cent reversal of a specific invoice, that is a new requirement against GL's posting, not a SOP workaround. This is in CM's batch for Femi; it is not asked of him separately.

### 2.2 Requirements (SOP)

**Deriving the credit note**
- **FR-SRS01 (M)** A credit note is issued for an INSPECTED return request. Its lines are derived from the request's lines: for each returned line, `quantity` = what was **received and accepted for credit** at inspection (not the quantity first requested), `net` = unit price x quantity (rounded once), `vatCategory` = the order line's stored category.
- **FR-SRS02 (M)** The person **does not type an amount**. The screen shows the derived lines, net per line and the total net; GL computes the VAT and the gross when it posts; SOP shows GL's gross after posting. (An override of the amount is out of scope: a different credit is a different return.)
- **FR-SRS03 (M)** Which dispositions earn credit is **not decided here** (Resaleable yes; Scrap, Repairable, Dispute stay open); until decided, only RESALEABLE lines are creditable and any other disposition answers 409 `disposition_not_creditable`.
- **FR-SRS04 (M)** `CreditNoteLine(salesOrderLineIndex, quantity, netAmount, vatCategory)` is stored (new table `credit_note_lines`, additive, V19) so the credit note is reproducible and auditable.

**Correct quantities**
- **FR-SRS10 (M)** The eligible quantity for a line is **derived**: ordered quantity minus the quantity already returned and credited on other (non-rejected) return requests for the same order line. It is never taken from the request. A request for more is 409 `exceeds_eligible_quantity` naming the line and the remaining quantity. (The existing `maxEligibleQuantity` field becomes read-only, filled by SOP.)
- **FR-SRS11 (M)** Return quantities accept the **same decimals as order quantities** (up to 4 places, `LineQuantity`), so 2.5 of 7.5 hours can be credited. Whole-number columns migrate additively.
- **FR-SRS12 (M)** Cumulative eligible quantity is checked under the per-order row lock the VAT correction route already uses, so two simultaneous returns cannot both take the last unit.

**Calling GL (needs GL's context route and lines shape)**
- **FR-SRS20 (M)** SOP reads `GET /companies/{id}/credit-note-posting-context` (period, AR control, Sales Returns, VAT control accounts) itself; the caller supplies **no** account or period id. GL answers 409 codes (`sales_returns_account_not_configured`, `vat_control_account_not_configured`, `no_open_period`) pass through with SOP's own code and GL's code and wording (the existing `glError` field), so WEB can say "add account 4900".
- **FR-SRS21 (M)** SOP posts `record-sales-return` in the **lines shape** with `Idempotency-Key: credit-note:{creditNoteId}` (the credit note id is created BEFORE the call and stored as PENDING, claim-first, the same pattern as sales and invoice emails), and `originalSupplyDate` = the date the order was created (the nearest stored fact; the cash-sale record date for a cash sale).
- **FR-SRS22 (M)** The GL answer is decoded tolerantly (the rule of 2026-10-11, already in SOP's gateway), `journalEntryId` and `status` required.
- **FR-SRS23 (M)** Outcomes: GL accepts -> credit note ISSUED with the journal entry id; GL refuses with a 4xx -> credit note FAILED, key not reusable for a different body, a corrected request gets a derived fresh key (the sale pattern); unknown outcome (timeout, 5xx) -> stays PENDING, retry reuses the same key and converges.
- **FR-SRS24 (M)** The legacy single-amount path stays callable until GL enforces D-SR5, then is removed from SOP in the same release.

**Screen contract (WEB)**
- **FR-SRS30 (M)** `POST /api/companies/{companyId}/return-requests/{id}/credit-notes` {date, description?} with `Idempotency-Key`: derives, posts, answers 200 {creditNote: {id, status, lines[], netAmount, vatAmount?, grossAmount?, journalEntryId}, returnRequest}. Errors: 404 `return_request_not_found`, 409 `return_request_not_ready_for_credit`, `disposition_not_creditable`, `line_vat_category_not_recorded`, `exceeds_eligible_quantity`, `credit_note_in_progress`, GL-originated errors with `glError`. Company in the path, WRITE at that Company, person token (service credentials refused).
- **FR-SRS31 (M)** `GET .../return-requests/{id}/credit-note-preview` returns the derived lines and total net **without posting**, so the screen can show what will be credited before the person confirms.
- **FR-SRS32 (S)** The existing flat `issue-credit-note` route is deprecated in the same release GL enforces; no known caller other than tests.

**Stock side (IM)** is independent in posting order: SOP's credit note does not wait for the stock receipt and the receipt does not wait for the credit note (GL half Q-SR3; the inspection already posts the receipt for RESALEABLE lines when IM's generalised goods-receipt exists).

### 2.3 Open questions
- **Q-SRS1 (Femi, in CM's batch):** which dispositions earn a credit besides Resaleable (Repairable after repair? Scrap at zero?). Default here: Resaleable only.
- **Q-SRS2 (CM/GL):** is the order creation date acceptable as `originalSupplyDate` for a credit sale, or should SOP start storing an invoiced-on date (V19, a few lines)? Recommendation: store it, it is the legally relevant date.
- **Q-SRS3 (Femi):** does a credit note also cancel the sale when every line is returned in full? Today a full CUSTOMER_CANCELLATION return moves the order to Cancelled (built); proposal: unchanged.

## 3. Use cases (U)

**UC-SRS1: Return and credit a VATable sale (main).** Customer returns 2 of 10 damaged items (STANDARD 23%, 100.00 each). Person opens the return request, inspects: 2 received, RESALEABLE. WEB shows the preview (1 line, 2 x 100.00 = net 200.00). Person confirms. SOP posts with key `credit-note:{id}`: GL books Dr Sales Returns 200.00, Dr VAT control 46.00, Cr AR 246.00. SOP shows gross 246.00, customer balance falls by 246.00.

**UC-SRS2: Mixed categories, one credit note.** Two returned lines, STANDARD and EXEMPT: net per line from each order line; GL books one VAT line for the STANDARD net only.

**UC-SRS3: A service line returned in part.** 2.5 of 7.5 hours (EXEMPT, 80.00): credit net 200.00, no VAT line.

**UC-SRS4: Timeout then retry.** GL posted but the answer was lost. The credit note is PENDING; the person retries (same key): GL replays the original entry, SOP marks ISSUED. No second posting.

**UC-SRS5: Over-return refused.** 10 sold, 8 already credited on another request: a request for 5 answers 409 `exceeds_eligible_quantity` (2 remaining); nothing posted.

**UC-SRS6: Old order, no recorded category.** An order stored before 2026-10-11: 409 `line_vat_category_not_recorded` naming the line; the person is told this order predates category recording.

**UC-SRS7: Company without a Sales Returns account.** GL's context answers 409 `sales_returns_account_not_configured`; WEB shows "add account 4900 to this business's chart"; nothing is saved as issued.

**UC-SRS8: Another Company or Tenant.** A return request, credit note or preview of another Company is 404; WRITE needed at the request's own Company; the Education Runtime credential has no such route.

## 4. Tasks (T)

| # | Task | Size | Depends on |
|---|---|---|---|
| R1 | V19 (additive): `credit_note_lines`, credit note PENDING/FAILED states and idempotency key column, decimal return quantities, `invoiced_on` on sales orders if Q-SRS2 says yes; domain + persistence + integration tests | 1 d | approval |
| R2 | Derivation: eligible quantity (cumulative, under the row lock), credit lines from inspection, category from the stored line, refusal codes; unit tests including the over-return and legacy-order cases | 1 d | R1 |
| R3 | Preview and issue routes (company-scoped), claim-first PENDING/ISSUED/FAILED, `glError` pass-through, isolation tests (other Company, Tenant, ER credential) | 1 d | R2 |
| R4 | GL calls: context read, lines-shape post with key and `originalSupplyDate`, tolerant decode, contract tests copied from GL's real DTOs | 0.5 d | GL S2, S4 deployed |
| R5 | Retire the legacy route when GL enforces; playbook and WEB contract sheet | 0.25 d | GL S5 enforce |
| R6 | Brief WEB with the exact routes, bodies, codes (before any release) | 0.25 d | R3 |

SOP total about **4 days** after approval, plus the stock leg (IM) and GL's 4.5 days.

## 5. Order (O): foundations first

1. **Foundation (SOP, no GL needed):** R1 and R2's eligible-quantity derivation can ship first and alone: they close the over-credit hole (defect 4) and the whole-number quantity limit (defect 5) on the existing route.
2. **GL first for the posting:** GL S1 (account), S3 (VAT direction in the VAT return), S2 (context route), S4 (lines shape), in GL's own order. SOP does not call the new shape before GL deploys it.
3. **SOP then:** R3 and R4, then R6, release behind WEB's screen.
4. **Cutover:** when GL enforces D-SR5, R5 removes the legacy route. Credit notes already posted without VAT stay as they are (pre-live data); an accountant corrects any real one.

## 6. Said plainly

- Until this lands, **no person screen should expose a credit note**: it would let a person post to arbitrary accounts, double-post on a retry, credit more than was sold, and misstate output VAT.
- The category copy frozen on the sale line (decision of 2026-10-11) is what makes this possible: the credit note reverses what the invoice charged, whatever IM's item says today.
