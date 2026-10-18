# SOP: which revenue account a sale posts to, today and proposed (SOP session, 2026-10-18)

**Status: short note, docs first, nothing built.** Femi, via CM: the account a transaction posts to is determined by the type of transaction through the Company's own chart ("the primary function of a General Ledger. Sacrosanct."), "Same with Sales", and when no account is set the amount goes to GL's Suspense account (3910), never to a default revenue account. GL is auditing every single-default path and designing a per-line account; this is SOP's side. Read in code at SOP master `6de3d08` and GL master.

## 1. How it works today (checked in code)

- **One revenue account for the whole sale, and SOP does not choose it.** `RecordOrdinarySaleUseCase` asks GL for the sales posting context and passes `context.revenueAccountId` to `RecordSaleUseCase` unchanged. GL's `ComputeSalesPostingContextUseCase` picks it as **the lowest-coded REVENUE-type account in the Company's chart** (`accounts.filter { type == REVENUE }.minByOrNull { code }`). That is a hidden default: add an account coded lower than the current "Sales" account and every sale silently moves to it.
- **The line carries no account.** `SalesOrderLine` has description, quantity, unit price, VAT category and an optional `itemId`. GL's `SaleLine` carries only a net amount and a VAT category. One entry is posted: Dr receivables (gross), Cr that one revenue account (net of all lines), Cr VAT control.
- **IM has no sales account on an item.** An IM item holds an inventory-asset account and a cost-of-sales account (used by IM's own postings), nothing for revenue.
- **Fee invoices (ER) would all go to the same account.** Tuition, boarding and transport lines would post to the single lowest-coded revenue account. A school's accountant could not report income by fee type from the ledger.
- The lower-level synthesis route (`POST /api/sales-orders/.../record-sale` style, caller supplies `revenueAccountId`) already lets a caller name an account, once for the whole sale (route in SalesOrderRoutes; not checked whether WEB uses it).

## 2. Proposal

**The line carries its own revenue account; GL resolves what is missing; SOP never invents a default.**

1. **A sale line gains an optional `revenueAccountId`** (the Company's account id, any REVENUE-type account of that Company). Stored on the line (additive nullable column on the order lines), echoed on the sale/invoice lines, frozen when the sale is recorded (a later change to an item or chart never rewrites an issued sale), exactly like the VAT category.
2. **Where it comes from, per kind of line:**
   - **Service and fee lines (no `itemId`): the caller names it on the line.** WEB's picker for a seller; ER sends the account on each fee line, held on ER's fee-schedule item, chosen by Finance and never defaulted by a machine (the same rule as the VAT category on the fee item). Tuition, boarding and transport are then different accounts because they are different fee items.
   - **Goods lines (with an `itemId`): the item's own sales account from IM, read next to the item's VAT category and selling price**, and the caller's value is ignored, the same rule as the VAT category. **This needs IM to add an optional sales (revenue) account to the item and return it on the item read** (IM's slice B already adds service items; the same field serves them). Ask of IM, not decided here.
   - **No account on the line and none on the item: SOP sends the line with no account, and GL credits Suspense (3910).** Femi's rule lives in one place (GL), so SOP, POP, HR and any future caller get the same behaviour. SOP does not look up or hard-code the Suspense account.
3. **What SOP sends GL.** GL's sale posting takes each line as `{ netAmount, vatCategory, revenueAccountId? }`. GL credits each distinct revenue account with its lines' net total in one entry (Dr receivables gross; Cr each revenue account; Cr VAT control), validates every account belongs to the Company and is REVENUE type, and answers a stable refusal per line otherwise. GL should also say in its answer which lines were not classified (went to Suspense), so SOP can show it. The sale-level `revenueAccountId` SOP sends today stays until GL ships the per-line field, then is dropped (**GL ships first**, and SOP declares any new answer field before GL adds it, because SOP decodes GL's answers strictly).
4. **Suspense is visible, not silent.** A sale that includes an unclassified line succeeds (the business cannot be blocked from selling) but its response and its invoice record carry `unclassifiedLines: [index...]`, so WEB can show "this sale has income not yet classified" and the owner can reclassify through GL's normal correcting entry. WEB decides how loud; the data is there.
5. **The picker WEB needs.** The Company's REVENUE-type accounts (code, name, active). GL already owns the chart, so this is a GL read of the chart filtered by type (WEB already reads the chart for the ledger screens); SOP adds no proxy. A seller chooses a revenue account per service line; a fee item (ER) is set by Finance. For goods, the account is shown from the item and not editable on the sale.
6. **Opening receivables and other callers** use the same mechanism: an itemised opening receivable whose contra is not yet classified credits Suspense by the same rule (the opening-figures design already uses Suspense for this).
7. **Existing data.** Every sale already posted keeps the single account it was posted to; nothing is rewritten. Stored lines without an account read as "classified at posting time under the Company's then-default".

## 3. What it costs and the order

| # | Piece | Owner | Est. |
|---|---|---|---|
| 1 | Per-line revenue account in GL's sale posting, Suspense when absent, unclassified lines in the answer, stable refusals | GL | GL's own |
| 2 | Optional sales account on an IM item and on the item read (goods, and the service items of slice B) | IM | IM's own |
| 3 | SOP: line field and column, request and response DTOs, use case passes it, goods lines read it from the item (ignore the caller), GL gateway sends per line, strict decode of GL's new answer, tests first | SOP | 1.5 d after GL's contract, plus 0.5 d fixtures |
| 4 | WEB: revenue-account picker on service lines, "not yet classified" indication | WEB | WEB's own |
| 5 | ER: `revenueAccountId` on the fee-schedule item (with ER's step A) and on each fee line | ER | ER's own |

SOP waits for GL's wire contract (1) and, for goods, IM's field (2). The S1 school fee route already built does not change: when this lands it simply accepts a per-line account for service lines.

## 4. Decisions needed

1. **Confirm GL resolves a missing account to Suspense** (not SOP), as Femi described.
2. **Goods item's sales account from IM** (the item wins, the caller is ignored), parallel to the VAT rule. Recommended.
3. **A sale line with an account that is not a REVENUE account of the Company is refused** (GL), never re-routed. Recommended.
4. Whether one entry credits several revenue accounts, or one entry per account. Recommended: one entry, several credit lines (one atomic fact).

## 5. Approved (CM, 2026-10-18): GL's per-line design, section 5 of `GL_Per_Line_Account_Routing_Audit_And_Design.md`

The proposal above is superseded where it differs, folded as follows:

- **At order time SOP copies the item's revenue account onto the sale line** (frozen, like the VAT category); IM adds `revenueAccountId` to items (Femi approved).
- **At record-sale SOP sends a per-line `accountId`**: goods lines carry the copied item account; service and fee lines carry the account the caller named (ER's fee item holds it) or **omit it, and GL posts Suspense 3910**.
- **Sales returns copy the original line's account** onto the credit/return posting, so a return reverses the same account the sale credited.
- **Sequence:** GL's step 1 is additive; step 2 (the contexts return Suspense instead of a default revenue account) releases together with SOP's sender. **SOP sends no `accountId` until GL's step-1 contract fixture exists**, then declares GL's new answer fields strictly before GL ships them.
- The AR plan's item 18 and the S1 fee route follow this: the fee route accepts a per-line account for service lines once the above lands.
