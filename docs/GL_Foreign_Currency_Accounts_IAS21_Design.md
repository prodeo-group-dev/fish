# GL foreign-currency cash and bank accounts: IAS 21 design (Phase 2a)

**Status:** design only, 2026-10-11, GL session. Nothing in this document is built. It is Phase 2a of `docs/GL_Cash_And_Bank_Books_SRS.md` section 9: the design pass Femi's extension ("a Company can open other cash/bank accounts denominated in other currencies as they wish", 2026-10-10) needs before any foreign-currency account is built. CM asked for it after the first slice and Release B (both built, held for release after the sitting). Several choices are Femi's; they are collected in section 10, with a recommendation each.

## 1. What this decides, and what it does not

**Decides:** how a cash or bank account can hold a currency other than the Company's, how money moves in, out and between such accounts, how the books and statements report it, and the order and size of the build.

**Does not:** foreign-currency customers and suppliers (SOP/POP invoicing in USD, foreign receivables and payables). `RecordFXRevaluationUseCase` already revalues a foreign receivable and stays as it is; extending sales and purchases to foreign currency is a separate SPUTO that can reuse what this builds. Also out: hedging, FX derivatives, translating a foreign subsidiary (IAS 21's other half), hyperinflation (IAS 29), and the Mano River currencies beyond what Femi names in section 10.

## 2. The standard, in the parts that matter here

- **Functional currency.** The Company has one: the currency of its main economic environment. Here it is the Company's base currency, which comes from its jurisdiction (decision D3, 2026-10-10). Everything is reported in it.
- **Initial recognition.** A foreign-currency transaction is recorded in the functional currency using the spot rate on the transaction date (a rate that approximates it, such as a week's average, is allowed where rates barely move) (IAS 21.21 to .22).
- **Monetary items** (cash and bank balances are monetary) are retranslated at the closing rate at each reporting date, and the difference goes to profit or loss (IAS 21.23 and .28).
- **Realised differences** arise when a foreign balance is settled or converted at a different rate from the rate it was carried at; also profit or loss (IAS 21.28).
- **Cash flows (IAS 7.25 to .28).** A foreign cash flow is translated at the rate on its date. The effect of exchange-rate changes on cash held in a foreign currency is not an operating, investing or financing flow; it is shown separately as part of reconciling opening to closing cash (IAS 7.28).

## 3. What GL has today (verified on master and on the held stack)

- `Money` always carries its currency and refuses to combine two. `Company.baseCurrency` is the reporting currency.
- `Account` has no currency. `JournalLine.amount` is a `Money`, and `JournalEntry.validateLines` requires the lines of each currency to balance on their own, so an entry cannot simply mix a USD line and a GBP line.
- Every report (trial balance, balance sheet, profit and loss, working capital, cash flow, and the new cash book) builds `Money` in the base currency and would throw on a foreign line.
- `FXRate` (from, to, rate, asOf, `convert`) and `RecordFXRevaluationUseCase` exist for one case: period-end revaluation of a foreign receivable, where the caller supplies the rate and the currently recorded home value and GL posts the delta to an FX gain or loss account the caller names. There is no rate table, no stored foreign amount, no FX gain or loss account in any chart template, no realised-gain calculation.
- Bank reconciliation refuses any currency but the Company's. The cash book, its routes and every cash/bank use case read the Company's base currency as the account's currency (each does it in one place, so a later account currency has a single seam to replace).
- The new cash and bank routes return money as plain decimal strings with one currency per response. EA decodes GL's balance-sheet and profit-and-loss responses strictly, so no field may be added to those responses without the consumer declaring it first.

## 4. The design choice: where the foreign amount lives

Three shapes were weighed.

**A. Foreign amount is the line's `amount`, with a base equivalent stored beside it.** Reports would sum the base equivalent. It is the truest to "the account is in USD", but it changes the meaning of `JournalLine.amount` for every consumer: every report, every service that reads lines, the per-currency balancing rule, all assume `amount` is in the base currency. A large, risky change to money that already works.

**B. Per-currency clearing pairs.** Use only today's per-currency balancing: debit the USD bank and credit an FX clearing account in USD; debit the clearing account in GBP and credit sales in GBP. No change to lines, but the clearing account's two currency balances must be revalued, every report still needs a translation layer, and the audit trail reads badly (one transaction as two entries pairs). Rejected as the long-term shape.

**C. Keep `amount` in the base currency; add the foreign amount and the rate as a memo on the line (recommended).** A line on a foreign account keeps `amount` as the base-currency value (so every existing total, report, balance and reconciliation of the base ledger is unchanged and still balances), and gains three nullable fields: `foreignAmount`, `foreignCurrency`, `fxRate`. The account's own currency balance is the sum of its lines' foreign amounts; its base carrying value is the sum of its lines' base amounts. Revaluation compares the two. Existing entries have null memo fields and are untouched.

Why C: it is additive (a nullable migration), it leaves the trial balance, balance sheet, profit and loss and cash flow correct and unchanged in the base currency from day one, it keeps EA's strict decoding and the four services' strict decoding of GL untouched, and it matches how the standard describes the books (the ledger is in the functional currency; the foreign amount is the transaction's original currency). A and B stay available if Femi wants them; they cost more and C does not preclude moving to A later.

## 5. The model

- **Account currency.** `Account.currency` (nullable ISO code); null means "the Company's base currency" so every existing account is unchanged. Only a cash or bank account (an ASSET with a `cashBookKind`) may have a foreign currency in this phase; the invariant is enforced in the aggregate and by a CHECK. Account `1000` stays in the base currency.
- **Foreign line.** A line on a foreign-currency account must carry `foreignAmount` and `foreignCurrency` equal to the account's currency and an `fxRate` (foreign to base) that reproduces the base amount to the currency's rounding. A line on a base-currency account carries none. The per-currency balancing rule is unchanged because every `amount` is in the base currency.
- **Rates.** A reference table `fx_rates (from, to, rate, as_of, source, entered_by)`, looked up as "latest on or before the date". Source options in section 10; whichever is chosen, a person can always override the rate on an entry, and an entry stores the rate it actually used, so the books never depend on a table row staying the same.
- **FX gain and loss accounts.** Two standard accounts in every business chart template (realised and unrealised, or one combined, see section 10), delivered to existing Companies by the existing "add missing standard accounts" use case.
- **Carrying cost.** A foreign balance's base carrying value divided by its foreign balance is its average rate (weighted average, section 10). Spending or converting part of it releases that share of the carrying value; the difference to the base value actually received or paid is the realised gain or loss.

## 6. How entries post

All of these use the existing idempotent entry use cases (entry id derived from the Idempotency-Key, insert-if-absent). The change is the lines they produce.

- **Receipt into a USD account (USD 100 for sales at rate 0.80).** Debit the USD bank GBP 80.00 with memo USD 100.00 at 0.8000; credit sales GBP 80.00. Balanced in GBP, unchanged shape.
- **Payment out of a USD account (USD 40, carried at an average 0.78).** Credit the USD bank for the carrying value GBP 31.20 with memo USD 40.00; debit the expense at the rate on the day GBP 32.00; the GBP 0.80 difference is a realised FX loss (debit). One balanced entry, three lines.
- **Transfer GBP to USD (GBP 100 buys USD 125, rate 0.80).** Debit the USD bank GBP 100.00 memo USD 125.00; credit the GBP bank GBP 100.00. No gain or loss at the moment of buying.
- **Transfer USD to GBP (USD 50 sold for GBP 39.50, carried at 0.78).** Credit the USD bank GBP 39.00 (memo USD 50.00); debit the GBP bank GBP 39.50; credit realised FX gain GBP 0.50.
- **Transfer between two foreign accounts (USD to EUR).** Both legs carry memo amounts; the base values are set from the rates, and the difference to carrying value is realised.
- **Undo.** Reverses lines mirror-image including the memo and the original rate, so the carrying value returns exactly (no gain or loss on an undo).

## 7. Period-end revaluation (unrealised)

At each period end, for each foreign cash or bank account: closing rate times foreign balance is the revalued base amount; the difference to the base carrying value is posted as unrealised FX gain or loss, one entry per account, against the account itself so the base carrying value moves to the revalued figure (and the average rate with it). This extends `RecordFXRevaluationUseCase`'s "post only the delta" shape from receivables to bank balances. It needs the closing rate (from the table) and a notion of period end, so it depends on the Period work (`docs/GL_Period_Management_Scoping.md`): until periods close, revaluation is an explicit action "revalue my foreign accounts as at this date", idempotent per account and date.

## 8. Reporting

- **Trial balance, balance sheet, profit and loss, working capital:** unchanged and correct in the base currency from day one (the point of choice C). Foreign balances are translated at the closing rate once revaluation has run; before it runs they are at carrying value, which is the historical-cost reading.
- **The book of a foreign account:** shows both figures per row (foreign and base), a foreign running balance (the real balance) and a base running balance; the opening, totals and closing in both. This is additive new fields on the cash-book responses, which no existing consumer decodes strictly (WEB reads them and the new section is not yet released).
- **Statement of cash flows (IAS 7):** the pool is all cash and bank accounts as now; foreign flows are at the entry's rate; a new line "effect of exchange-rate changes on cash" equals the closing pool balance in base less the opening plus the net of the flows in base. Adding a field to the cash-flow response is the one change touching a report EA reads: EA's strict decoder must declare the field before GL ships it (consumer-first), or the line is delivered in a separate response.
- **Reconciliation:** a foreign account is reconciled in its own currency: the statement, its ending balance and its lines are in the account's currency and are compared with the account's foreign balance and foreign amounts. A realised FX difference on a matched line posts as a separate adjustment entry, not inside the match. `CurrencyMismatch` changes from "must be the Company's currency" to "must be the account's currency".

## 9. Build plan, order and size (GL days, rough, tests and mutation checks included)

| # | Task | Depends on | Days |
|---|---|---|---|
| F1 | `Account.currency`, foreign memo on `JournalLine`, invariants, migration (nullable columns, CHECK), persistence | none | 2.5 |
| F2 | FX rate table, lookup, entry and override; standard FX gain and loss accounts in the templates and in the standard-accounts use case | F1 | 2 |
| F3 | Receipts and payments in a foreign account with rate capture, foreign and base balances, books with both columns | F1, F2 | 3 |
| F4 | Transfers across currencies, realised gain or loss at weighted-average cost, Undo mirroring the memo | F3 | 3 |
| F5 | Revalue foreign accounts (unrealised), idempotent per account and date | F2, F4 | 2.5 |
| F6 | Cash flow: effect of exchange-rate changes on cash (consumer-first with EA) | F4 | 2 |
| F7 | Reconciliation in the account's currency | F3 | 2 |
| F8 | Services settle into a foreign account (SOP collection, POP payment, HR pay run, IM settlement): rate capture on GL's side; the services' own request changes are theirs | F3 | 3 |
| F9 | Isolation matrix, concurrency, mutation checks across F1 to F8 | all | 3 |
| | **Total GL** | | **about 23** |

This replaces the earlier provisional 14.5 days in SRS section 9.6: with the carrying-cost, revaluation and cross-currency transfer work spelled out, 23 is the honest figure. WEB, SOP, POP, HR and IM are in addition and are theirs to size. A useful first release that stops short of the hard parts: **F1, F2, F3, F7 (about 9.5 days)**: foreign accounts you can receive into, pay out of and reconcile, with the base ledger correct, but no cross-currency transfers, no automatic gain or loss on conversion, and no revaluation yet (so a foreign balance is shown at carrying value only, and the book says so). Not recommended as a place to stop for long, because a foreign account without realised and unrealised differences misstates profit; it is an incremental route, not a finished one.

## 10. Questions for Femi (his call), each with a recommendation

1. **Which currencies may a Company open?** Recommendation: a curated list per Company chosen from ISO currencies that GL has a rate source for, starting with GBP, EUR, USD, NGN, SLE; others added as data. For the Mano River four, LRD, GNF and XOF are not onboarded (the standing decision) and GNF and XOF are zero-decimal, so they would be `Money`'s first of that kind: allow only after an explicit decision.
2. **Where do rates come from?** Options: typed by the person on each entry; a table GL fills from a published source; both with the table as the default and a manual override. Recommendation: the table with a manual override, and an entry always stores the rate it used. The table needs a source (central-bank or a provider) and someone accountable for keeping it current; without one, typed rates only.
3. **Realised gain or loss cost flow:** weighted average (recommended: simple, no lots to track) or first-in first-out.
4. **FX gain and loss accounts:** one combined account, or two (realised and unrealised)? Recommendation: two, because the standard and most users want them apart.
5. **Revaluation:** explicit "revalue as at date" now and automatic at period close once Period close exists (recommended), or automatic from the start.
6. **Is Company-currency reporting enough?** (the functional currency equals the reporting currency: recommended), or will any Company need to present in another currency (IAS 21 presentation-currency translation, a much larger piece).
7. **Foreign customers and suppliers:** in scope for a later SPUTO that reuses this build? (recommended), or part of this one.
8. **Order:** build Phase 1 (held, approved) first and ship, then F1 to F9; or hold the Cash Book until foreign accounts are designed (not recommended: Phase 1 is complete and unaffected).

## 11. Risks

- **Rate quality is a product risk, not a code risk.** A wrong or stale rate silently misstates profit. The books must show the rate used on every foreign row, and revaluation must name the rate and its date.
- **Rounding.** Base amounts are rounded to the base currency's digits; a memo rate that reproduces the base amount to the cent is required, so a foreign line is stored with its rounded rate or its base amount is authoritative. The design makes the base amount authoritative and the rate informational.
- **Period dependency.** Unrealised revaluation is only as good as the Period model; until month-end close exists it is an explicit action.
- **EA's strict decoding** limits where report fields can be added (section 8); handled by ordering, not by tolerating unknown fields.
- **Zero-decimal currencies** (GNF, XOF, JPY) test `Money`'s scale handling, which has not been exercised.

## 12. Recommended order

Ship Phase 1 after the sitting. Then, on Femi's answers to section 10: F1, F2, F3, F7 as the first foreign-currency release; F4, F5, F6 next as one release (they are what makes the profit figure right); F8 and F9 alongside each. Each release is held for CM review at HIGH as with the first two.
