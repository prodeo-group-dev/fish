# SOP owns Accounts Receivable: completeness assessment (SOP session, 2026-10-18)

**Status: assessment and plan, docs only, nothing built.** Femi, via CM: "Accounts Receivable is a primary function of SOP" (as Accounts Payable is POP's), and "Let them do their own aging. GL aggregates." So SOP owns the receivables subledger end to end, including ageing by due date and by customer; GL keeps the control account (1100) and totals; GL's tag-derived AR ageing stops being a source for screens. Read in code at SOP master `6de3d08` (sales, collections, returns, credit notes, customers) and GL master (what GL offers). Estimates are builder-days of the SOP session including tests, mine and unproven, excluding review and other sessions.

## 1. Where AR lives today

- **SOP holds the invoice** (a `SalesOrder` with lines, net, VAT, gross as GL posted it, status, `collectedAmount`) and calls GL to post. **GL holds the money fact** (journal lines on 1100) and derives *customer balances* and *AR ageing* from the CUSTOMER tag on those lines (`ComputeCustomerBalancesUseCase`, `ComputeAccountsReceivableAgingUseCase`). SOP's `GET /customers-with-balances` simply asks GL for those balances. So today the subledger SOP is meant to own is **not computed in SOP at all**: the screens read GL's tag-derived view.
- SOP stores **one cumulative number** per invoice (`collectedAmount`), not the individual receipts. A credit note posts to GL but **does not reduce the invoice's open amount in SOP** (it only cancels the order when every line is returned in full).

## 2. Coverage, item by item (priority order = build order)

| # | AR capability | State | What exists / what is missing | Where it belongs | Est. |
|---|---|---|---|---|---|
| 1 | **Due date on every invoice, from credit terms** | **Missing** | `Customer.creditTerms` is free text; no due date anywhere on a sale or invoice (only Bills for Collection have one). Needs the shared terms list (POP's note) and a stored `dueDate` on the sale at creation. Prerequisite of ageing, overdue, dunning. | SOP | 1.5 d |
| 2 | **Receipts register** (each collection as its own record: date, amount, currency, settlement account, ledger entry id, reference, payer, key) | **Missing** (only the running total) | Collections post and update the total, but no receipt is kept. Needed for statements, part payments shown line by line, third-party payers, receipt numbers, and reversing a mistaken receipt. Existing totals become one opening "legacy" receipt per invoice. | SOP | 1.5 d |
| 3 | **Credit notes applied to the invoice** | **Partly** | Credit note issue and ledger posting exist (returns inwards); the invoice's open amount ignores them, so SOP's open-item view would overstate what is owed. Add a credited amount (allocation) per invoice. | SOP | 1 d |
| 4 | **Open items and AR ageing by due date and by customer** | **Missing in SOP** (GL has a tag-derived version) | New read: open amount = gross - receipts - credits per invoice; buckets Current / 1-30 / 31-60 / 61-90 / 90+ days past due at an `asOf` date; per customer and totals; undated invoices (custom terms with unknown days) shown as their own total, never in Current. | SOP owns, exposes | 1.5 d |
| 5 | **Customer balances from the subledger** | **Partly** (works, but from GL tags) | Same sum as item 4 by customer; replaces the GL read behind `customers-with-balances`. | SOP | 0.5 d |
| 6 | **Reconciliation: subledger total = GL 1100** | **Missing** | Compare the sum of open items to GL's balance of account 1100 as of the same date; show the difference and the invoices/postings not explained (manual journals to 1100, opening balances, posting failures). Opening receivables must be itemised in SOP (already decided) so they are inside the subledger. GL provides the 1100 balance (existing trial-balance read). | SOP computes, GL supplies the control figure | 1 d |
| 7 | **Customer statement** (invoices, credit notes, receipts in date order with running balance, per customer and period) | **Missing** | Needs items 2 and 3. JSON first, PDF and email using the existing invoice PDF/SES machinery second. | SOP | 1.5 d (+1 d PDF/email) |
| 8 | **Receivables summary for the dashboard** (total owed, overdue total, count, oldest overdue) | **Missing in SOP** | One small read for EA/WEB, replacing the GL summary for the "Customers owe you" tile. | SOP | 0.5 d |
| 9 | **Invoice register** | **Built** | `GET /api/sales`, invoice read route, invoice email with audit, PDF. Add due date, open amount and credited amount to the rows once 1-3 land. | SOP | 0.25 d |
| 10 | **Partial collections** | **Built** (total only) | Part payments accepted, status PARTIALLY_COLLECTED, "paid in full" judged against the gross. Gets proper detail from item 2. | SOP | in 2 |
| 11 | **Credit notes and returns inwards** | **Built** for returns; **missing** as a free-standing credit note against part of an invoice | The return flow credits returned lines; "credit part of this invoice" has no route (waiting on Femi's approval of the returns/credit-notes design). | SOP + GL | per that design |
| 12 | **Credit limits** | **Missing** | No numeric limit exists on a customer. Needs a limit on the customer and a rule at sale time. Femi to choose: block or warn. | SOP | 1 d |
| 13 | **Dunning / overdue follow-up** | **Missing** | Overdue list comes free from item 4. First version: a manual "send reminder" per overdue invoice or statement by email (existing SES machinery, rate limits and audit); no automatic sending. | SOP | 2 d |
| 14 | **Third-party payers** (someone other than the customer pays) | **Missing, waiting on Femi** | Needs item 2 (payer on the receipt). | SOP | with 2, per Femi |
| 15 | **Discounts given** | **Missing, waiting on Femi** | Settlement discounts also need a VAT decision (full SPUTO first, per Femi). | SOP + GL | per Femi |
| 16 | **Opening receivables upload** (first cohort) | **Missing** | Itemised per invoice, contra Suspense, from the opening-figures design; must enter the subledger so item 6 reconciles. | SOP | 2 d |
| 17 | **Write-off of bad debts / expected credit loss** | **Missing in SOP** | GL has the ECL posting; SOP has no way to mark an invoice written off or provisioned. Later. | SOP + GL | 2 d |
| 18 | **Revenue account per line** | **Missing** (hidden single default today) | See `SOP_Sale_Revenue_Account_Per_Line_Note_2026-10-18.md`; Suspense when absent. Not AR ageing, but AR's posting must be right. | GL first | 2 d SOP |

Totals for what is not waiting on Femi: items 1-8 about 9 d (plus 1 d for statement PDF and email); items 9, 12, 13, 16 and 17 about 7.25 d more.

## 3. What belongs where

- **GL**: the control account 1100 and its balance, journal postings, trial balance, and aggregation. Its tag-derived customer balances and AR ageing stay as a **comparator for the reconciliation only** and are retired as a source for any screen (Femi's rule). GL need not change for items 1-8 except providing the 1100 balance (already readable).
- **SOP**: everything customer-facing: due dates, receipts, credit applications, open items, ageing, balances, statements, reminders, limits, reconciliation.
- **EA / WEB read from SOP**, not GL, for: receivables ageing, customer balances, the dashboard summary.

## 4. What SOP must add so the dashboard and WEB read ageing from SOP (the read contracts)

All Company-scoped, read access to Sales at that Company; money as plain decimals with currency; strict JSON so EA/WEB mirror them with fixtures.

1. `GET /api/companies/{companyId}/receivables-ageing?asOf=YYYY-MM-DD` returns `{ asOf, currency, buckets: [{ label, fromDays, toDays, amount }], undated: amount, total, customers: [{ customerId, name, buckets..., undated, total }] }`.
2. `GET /api/companies/{companyId}/receivables-summary` returns `{ asOf, currency, totalOwed, overdue, overdueCount, undated, oldestOverdueDays }` (the dashboard tile; EA mirrors it).
3. `GET /api/companies/{companyId}/receivables-reconciliation?asOf=` returns `{ asOf, subledgerTotal, glControlBalance, difference, unexplained: [...] }`.
4. `GET /api/companies/{companyId}/customers/{customerId}/statement?from=&to=` returns the ordered lines and running balance.
5. The existing invoice and sales-list rows gain `dueDate`, `openAmount`, `creditedAmount` (additive).

Currency: one currency per Company for now (the platform is SLE-only in the Mano River operation); a mixed-currency Company would need per-currency buckets, flagged not built.

## 5. Order, and what blocks what

1 (with POP's terms note, EA default later) -> 2 and 3 together -> 4, 5, 8 -> 6 -> 7 -> 9. Items 12, 13, 16, 17 follow. 14 and 15 wait on Femi. Item 18 runs in parallel with GL first. **Prerequisites already decided:** the terms list gives due dates (item 1); the per-line revenue account with Suspense as fallback keeps what AR posts right (item 18). Backfill: existing invoices have no due date and get none invented: they show as undated until terms exist for them.

## 6. Decisions needed from Femi

1. **Credit limit: block or warn** a sale that would exceed it (item 12).
2. **Reminders: manual only at first** (recommended), or automatic from day one (item 13).
3. Items 14 and 15 (third-party payers, Discounts Given) are already with Femi.

## 7. Addendum: the dashboard summary EA asked for (2026-10-18)

EA's cut-over note asks for `GET /companies/{c}/receivables-ageing-summary` (Company-scoped, the caller's own token) returning `{ currency, asOf, totalOutstanding, overdueTotal, overdueCount, overdueBasis: "INVOICE_DATE_30" | "DUE_DATE", undatedAmount }`, decimals as strings, `409 multiple_currencies`. This **is** item 8 above (the name and shape are aligned to EA's; `/receivables-summary` is dropped). SOP states the basis:
- **Available first, before the terms build, with `overdueBasis: "INVOICE_DATE_30"`** (an invoice is overdue 30 days after its invoice date) and `undatedAmount: "0.00"`. It is only honest once SOP knows each invoice's open amount, so it comes **after the receipts register and the credit-note application (items 2 and 3, about 2.5 d), plus 0.5 d for the endpoint: about 3 d**. SOP will not ship it earlier: today `collectedAmount` ignores credit notes, so an earlier figure would overstate what is owed.
- **After the terms build (item 1) the basis becomes `DUE_DATE`** when every open invoice has a due date. If any open invoice is undated (legacy), the whole figure stays `INVOICE_DATE_30` so one response never mixes bases; the legacy invoices are not given invented due dates.
- Totals always from GL 1100 on EA's side, SOP's overdue replaces GL's only when SOP's open-item total reconciles (item 6); EA labels the source.
- A contract fixture (the response, and the `multiple_currencies` refusal) ships with the endpoint, per the T2/T9 mechanism.
