# GL: the account a transaction posts to is chosen by the type of transaction (P0 audit and design)

GL session, 2026-10-18. Docs only: nothing in this note is built. For CM's HIGH review, then build.

**The principle (Femi, 2026-10-18, via CM):** the account a transaction posts to is determined by the type of transaction (rent, electricity and consultants each post to their own account from the Company's own chart). "This is the primary function of a General Ledger. This is sacrosanct." The same applies to sales (goods, services, fees, interest each to its own revenue account). **If no account is set, the amount goes to the Suspense account (3910), never to some default account** ("Why else would there be GLaaS?"). Suspense is cleared later by the accountant's ordinary reclassification journal, and the Live-switch checklist gets "Suspense is zero".

**Reference posting, approved by Femi ("Perfect"):** a purchase of rent, net 1,000.00 plus 20% VAT.
- At the match: Dr 5100 Rent (the account chosen for the line) 1,000.00; Dr 2150 VAT Control 200.00 (input VAT, tagged `VAT_DIRECTION=INPUT` and the category); Cr 2000 Accounts Payable 1,200.00 (tagged to the supplier).
- At payment: Dr 2000 AP 1,200.00; Cr 1000 Cash (or the bank account) 1,200.00.
- With no account set, the net debit goes to 3910 Suspense instead of 5100.

Scope statements from CM (Femi's words): the same rule for Sales, Sales Returns, Discounts Given and credit notes; "Let them do their own aging. GL aggregates" (section 6); "Likewise Payroll, and Fixed Assets" (section 6; the Fixed Assets extraction assessment is a separate note).

---

## 1. Audit: how each posting path chooses its account today

Evidence is from reading GL's code on master (tip 29cd6bc plus my local branch) and the callers in POP, SOP, IM and HR. "Verified" means I read the line; "not traced" means I did not follow the caller.

### 1.1 The defect (the single default that must go)

| # | Path | How the account is chosen today | Correct rule |
|---|---|---|---|
| A | **Purchase obligation** (`POST /purchasing/record-obligation`, used by POP at three-way match) | **One** request-level `expenseOrAssetAccountId` for the whole net amount. GL checks only that it belongs to the Company. The caller gets it from `GET /purchase-posting-context`, which returns the **lowest-coded EXPENSE account** (`ComputePurchasePostingContextUseCase`: `filter EXPENSE ... minByOrNull code`). POP passes it unchanged (`PurchaseOrderFulfillmentRoutes.kt:269`). On a standard business chart that is 5000 Operating Expenses, for every purchase of every kind. | One account **per line**, from the Company's chart: the line's own account, else the item's default (IM `Item.expenseAccountId`, which exists now), else Suspense. |
| B | **Sale** (`POST /sales/record-sale`, used by SOP) | **One** request-level `revenueAccountId`. Same shape: the sales context returns the **lowest-coded REVENUE account** (`ComputeSalesPostingContextUseCase`); SOP passes it for every line (`RecordOrdinarySaleUseCase.kt:224`). GL's own `CreateSalesInvoiceUseCase` (line 141) has the same lowest-code rule. | One revenue account per line (goods, services, fees, interest), else Suspense. |
| C | **Supplier credit note** (`POST /purchasing/record-credit-note`) | Credits the Company's 4920 Discounts Received (REVENUE, validated), found by code in the purchase context. One account for every credit note line. | 4920 stays the default for a discount or rebate (Femi's earlier decision). Whether a credit note line for returned or mis-billed goods may credit the original expense account instead is a decision (D4). |
| D | **Sales return** (`POST /sales/record-sales-return`) | Caller supplies `salesReturnsAccountId`; GL checks only the Company. **The standard chart has no Sales Returns account** (playbook OS-GL-N13), and I did not trace which account SOP's `IssueCreditNoteUseCase` or `InspectReturnedGoodsUseCase` is given by their callers. | A contra-revenue debit that mirrors the revenue account of the original sale line; Suspense when unknown. |
| E | **Discounts Given** | No account and no posting path exist (decided, not built). | Same per-line rule as D when built. |

### 1.2 Paths that are already by-type, or correctly generic

| Path | How the account is chosen | Verdict |
|---|---|---|
| Inventory receipt / issue (IM) | The item carries its own inventory asset and COGS accounts (`Item.inventoryAssetAccountId`, `cogsExpenseAccountId`); the issue contra defaults to the item's COGS and can be overridden; the receipt contra is the AP control account. | Correct by design (IM owns it). The AP/inventory double count (seam A, GRNI) is a separate known item. |
| Payroll (`record-pay-run`, leave accrual) | Wages 5200, salaries 5300, leave expense 5400, accrued leave 2200, cash 1000, by code from `ChartOfAccountsTemplate` (`ComputePayrollPostingContextUseCase`). PAYE and employer costs go as ledger liabilities through the generic journal route, chosen by HR. | By pay type already (wages vs salaries). Payment is always from 1000 (see 1.3 F). Section 6 covers Payroll's ownership. |
| Fixed assets | The caller supplies `fixedAssetAccountId`, `depreciationExpenseAccountId`, `accumulatedDepreciationAccountId`, disposal and impairment accounts. Funding is Cash, On account (AP) or **Already owned, which credits Suspense**. Import takes the asset account by code. | By-type in the request; no GL default. The Suspense mechanism already exists here. The asset-category-to-account rule belongs to the Fixed Assets assessment. |
| Expected credit loss, FX revaluation | Caller supplies expense and allowance (or receivable and gain/loss) accounts. | Correct. |
| Cash book entry | The person picks the counter-account from `GET .../cash-books/{id}/counter-accounts`, which already filters out control, module-owned, cash-book and inactive accounts (`ListCounterAccountsUseCase`, `ModuleOwnedAccounts`). | **This is the model to reuse** for the per-line pickers. |
| Opening figures and imports | Generic GL balance rows to an account that a sub-ledger owns are redirected to Suspense; fixed-asset "already owned" credits Suspense. | The precedent for the fallback. |
| POP opening AP lines | POP passes the Suspense account as the expense account (`ImportOpeningApLineUseCase.kt:111`). | Correct already. |

### 1.3 Related defects found on the way

- **F. Settlement account is always Cash 1000.** Both posting contexts return the cash account (code 1000) as the settlement account, and payroll pays from 1000. Femi's cash-book decision is that bank accounts are further cash books, so a payment or collection made from a bank account has no way to be chosen through the context. I did not trace whether POP or SOP let the user pick one. This is the settlement side of the same principle (which account the money moved through); I recommend the same per-transaction optional field (`settlementAccountId`) and a check with POP and SOP. Not in this build unless Femi wants it (D5).
- **G. GL does not validate the account's type or its being a control account on these routes.** Record-obligation, record-sale and record-sales-return check only "same Company". An EXPENSE debit can land on a REVENUE, LIABILITY or control account (AP 2000, VAT 2150, AR 1100) and GL accepts it. Only the credit note validates its account's type. Per-line accounts need this validation (section 3.3).
- **H. Input VAT lines on record-obligation carry no `VAT_DIRECTION` tag.** Only the credit note tags `VAT_DIRECTION=INPUT`. The VAT return falls back to the debit/credit side when the tag is absent, so today's return is right, but the approved reference posting says tagged. Add `INPUT` (purchase) and `OUTPUT` (sale) tags in the same change; additive, same VAT return result.
- **I. Individual charts reuse codes** (1100 Investments, 2000 Loans, 4000 Salary Income, 5000 Living Expenses). The posting contexts look up business codes, so they are not meaningful for an Individual Company. Out of scope here; noted so nobody builds on it.
- **J. A business chart seeds one expense account** (5000 Operating Expenses) plus payroll, cost of sales, interest, tax and depreciation. Rent, electricity and consultants do not exist until the owner creates them (`POST /companies/{id}/accounts` exists). The owner flow in section 4 must make "create an account" one step from the picker.

### 1.4 What the stopgap costs today

Every purchase of every kind debits 5000 Operating Expenses; every sale credits 4000 Sales Revenue. The trial balance, P&L and VAT return are internally correct but the P&L has no rent/electricity/consultancy detail, which is the point of a ledger.

---

## 2. Design principles

1. **Consumer-first.** New field on each line, optional. Old callers that send no line account keep working (with the behaviour change in 2.2).
2. **The Company's own chart only.** Every account id is validated against the Company, type and usability. A foreign Company's id is "not found", never "forbidden" (existing convention).
3. **Fallback is Suspense and nothing else.** No lowest-code rule survives anywhere.
4. **GL does not guess.** GL never infers an account from a description. The caller (POP from the IM item, SOP from the IM item or the line, a person from the picker) supplies it.
5. **Validation lives in GL**, one shared rule, so a screen never offers what GL would refuse (the cash-book picker's approach).

### 2.1 Request shape

`POST /purchasing/record-obligation` (and the same on `record-sale`):

```
lines[]: { netAmount, vatCategory, accountId?: String }      // NEW optional per line
expenseOrAssetAccountId?: String                              // existing, now optional (legacy)
```

Resolution per line, in order:
1. `line.accountId` if present: validated (3.3), used.
2. else the request-level `expenseOrAssetAccountId` if present (legacy callers): validated by the same rules.
3. else GL's Suspense account, found by code 3910 on the Company. If the Company has none: refuse `suspense_account_not_configured` (409). The owner fixes it with the existing `POST /companies/{id}/standard-accounts`, which already adds missing standard accounts including Suspense.

Posting: one debit line **per distinct account** (net amounts summed), VAT lines per category exactly as today (now tagged with direction), one AP credit (gross) tagged to the supplier. Totals must balance by construction; a test asserts it.

Sales mirror: one credit line per distinct revenue account, VAT credits per category (tag `OUTPUT`), one AR debit (gross) tagged to the customer.

### 2.2 Behaviour change (retiring the stopgap) and how to sequence it

The lowest-code expense/revenue fallback lives in the **posting contexts**, which return `expenseOrAssetAccountId` and `revenueAccountId`. Retiring it means those context fields stop returning 5000/4000:

- `GET /purchase-posting-context`: `expenseOrAssetAccountId` returns the **Suspense account id**; new field `suspenseAccountId` (same value, honest name). `ExpenseAccountNotConfigured` is replaced by `SuspenseAccountNotConfigured`.
- `GET /sales-posting-context`: same for `revenueAccountId`.

**Consequence you should know before approving:** the moment the contexts flip, POP and SOP (unchanged) post **every** purchase and **every** sale to Suspense, because neither sends a per-line account yet. Revenue and expense reports then show nothing but Suspense until they do. That is correct under the rule but only useful once POP and SOP send accounts. Recommended order:

- **Step 1 (additive, no behaviour change):** GL ships per-line `accountId`, the validation, the account list (section 4), the direction tags and the Suspense fallback **when the request sends no account at all**. Contexts unchanged.
- **Step 2 (the retirement):** POP and SOP ship per-line senders (POP from the IM item's `expenseAccountId`; SOP from a new IM/line source, D2), then GL flips the two contexts to Suspense in one release, announced to both.

Femi says legacy test data is cheap, so D1 asks whether to flip immediately instead of waiting for step 2.

### 2.3 Refusal codes (400/404/409, `errorResponseJson` style)

| Code | HTTP | Meaning |
|---|---|---|
| `line_account_not_found` | 404 | The id is not an account of this Company (including another Company's). Detail: the id. |
| `line_account_not_allowed` | 400 | Found, but not usable on this kind of line. Detail: id and reason `wrong_type`, `control_or_module_owned`, `inactive`. |
| `suspense_account_not_configured` | 409 | No line account was given anywhere and the Company has no 3910. |
| `vat_rate_not_in_force` / `vat_category_not_supported` | 400 | Unchanged (the 2026-10-17 fix). |

### 2.4 Validation rule (shared)

A line account is usable when it is of this Company, active, and:
- **Purchase line:** type EXPENSE, or type ASSET that is not module-owned (a prepayment, for example); **or** the Company's Suspense account.
- **Sale line:** type REVENUE; **or** Suspense.
- **Sales return / discount-given line:** type REVENUE (contra); **or** Suspense.
- Never a control or module-owned account: the same `ModuleOwnedAccounts.useInstead(account, clientType) == null` test the cash-book counter-accounts use (excludes 1100, 2000, 1300, 1200/1210, VAT 2150, 4920 Discounts Received, 3900/3910 except as the explicit Suspense case, and any cash or bank book).
- Inventory (1300) and fixed assets (1200) are reached only through IM and the Fixed Assets flow.

### 2.5 Credit notes and returns

- Supplier credit note: `lines[].accountId?` optional, default 4920 as today. If D4 is yes, a line may instead credit an EXPENSE account (the original expense account), validated by 2.4.
- Sales return: `salesReturnsAccountId` stays; add per-line `accountId?` for the revenue account being reversed; absent means the single `salesReturnsAccountId`; absent as well means Suspense. Recommend SOP copies the original sale line's account onto the return line.
- Discounts Given: not built; when built it takes the same per-line contra-revenue shape.

---

## 3. Tests (written first)

Use cases, with the `FakeJournalEntryRepository` style already in use:

1. **Reference case:** rent 1,000.00 STANDARD (UK 20%) to "5100 Rent", one line; asserts Dr 5100 1,000.00, Dr 2150 200.00 tagged `VAT_CATEGORY=STANDARD` and `VAT_DIRECTION=INPUT`, Cr 2000 1,200.00 tagged to the supplier; entry balances.
2. **Two lines, two accounts, two VAT categories:** rent 1,000.00 STANDARD (200.00) to 5100 and electricity 400.00 REDUCED 5% (20.00) to 5110: Dr 5100 1,000.00, Dr 5110 400.00, Dr 2150 200.00 and 20.00 as two category lines, **one** Cr 2000 1,620.00; debits equal credits.
3. **Two lines, same account:** summed into one debit line.
4. **No account anywhere:** net goes to 3910 Suspense; VAT and AP unchanged; Company without 3910 is refused `suspense_account_not_configured` and nothing is saved.
5. **Legacy caller:** request-level `expenseOrAssetAccountId` only: behaves as today (all lines to that account).
6. **Refusals, nothing saved:** another Company's account (`line_account_not_found`); a REVENUE account on a purchase line; 2000/2150/1100/1300 (control or module-owned); an inactive account; each with its detail.
7. **Sale mirror** of 1 to 6 with revenue accounts and `OUTPUT` tags.
8. **Credit note** and **sales return:** per-line account and default paths.
9. **Route tests:** the new refusal codes with their status codes and the legacy request body unchanged; the context test for the Suspense flip (step 2) and its not-configured code.
10. **Contract fixture** in `fish-contracts` (a PR for CM): record-obligation with two lines carrying accounts, the same for record-sale, and the context response with `suspenseAccountId`. Fixture-first, so POP/SOP/IM pin to it.
11. **Mutation checks:** remove the type check, the control-account check, the Company check and the Suspense fallback in turn; each must fail a test.

---

## 4. The Company's account list for owners to choose from

Reuse the existing chart read, `GET /companies/{companyId}/accounts` (returns active accounts sorted by code with id, code, name, type, classification, cashBookKind), and extend it additively:

- `?type=EXPENSE|REVENUE|...` filter.
- `?usableFor=purchase-line|sale-line|sales-return-line` applies rule 2.4, so the list contains exactly what GL would accept (Suspense included as the last, labelled choice). Same principle as `counter-accounts`: a screen never copies the exclusion list.
- Response gains `expenseClassification` (already stored) so the picker can group (Cost of sales, Operating, Interest, Tax), and a `usable` flag when the full list is requested.
- "Create the account you need" is the existing `POST /companies/{id}/accounts`; WEB links to it from the picker.

Access is the existing read/write authorization; nothing new on the permission model.

---

## 5. Who does what (shape for POP, SOP, IM, WEB, EA)

- **GL (this design):** per-line `accountId`; validation; Suspense fallback; direction tags; the filtered account list; contexts flip in step 2; contract fixtures; docs/playbook.
- **POP:** at match, send each line's `accountId` = the line's chosen account, else the linked IM item's `expenseAccountId`, else omit (GL posts to Suspense). POP's line aggregate keeps no account of its own (its comment says routing happens at the GL call); it needs an optional `accountId` on the PO line or it reads it from IM at match time (POP and IM to choose; I recommend reading from IM at match, per the "copy at order time, never changes" rule used for VAT category). Credit notes: same.
- **IM:** already stores `expenseAccountId` for service and expense items. For sales it has **no revenue account** on the item (verified: no field); a new optional `revenueAccountId` on service items and on stock items (sales revenue for goods) is the natural source, set by a person with the same audit trail as `expenseAccountId`. IM validates it against GL's account list (`usableFor=sale-line`) as it does for the expense account.
- **SOP:** at order time copy the item's revenue account onto the sale line (frozen like the VAT category), send per-line `accountId` at `record-sale`; sales returns copy the original line's account.
- **WEB:** the purchase and sale line forms show the account (defaulted from the item, changeable via the picker, "not sure" = Suspense), and Suspense balance on the owner dashboard once step 2 is live.
- **EA:** nothing for the posting; the "Suspense is zero" Live-switch check can read the Suspense balance from GL's trial balance.
- POP's, SOP's and IM's GL gateways each define a lenient Json (`ignoreUnknownKeys = true`: `ktor_gl_engine_gateway.kt` in each); I did not check that the posting-context fetch specifically uses it, and HR's gateway I did not read for this. So adding a field to a context response is probably safe but not proven: the contract fixtures are the guard, and the context change ships fixture-first.

---

## 6. What GL aggregates, and what moves to the sub-ledgers (CM, Femi 2026-10-18)

"Let them do their own aging. GL aggregates." "Likewise Payroll, and Fixed Assets." Each sub-ledger owns its own records; GL keeps control accounts, totals and statements, and receives journals.

| Area | Owner of the records | GL keeps |
|---|---|---|
| Accounts Payable (suppliers, invoices, ageing) | POP | Control account 2000, its balance, the statements |
| Accounts Receivable (customers, invoices, ageing) | SOP | Control account 1100, its balance, the statements |
| Payroll | HR/Payroll (the split is under way) | Wages/salaries/leave expense, PAYE and employer liabilities, cash; journals received |
| Fixed assets | A Fixed Assets service (assessment is a separate note) | 1200 cost, 1210 accumulated depreciation, 5500 depreciation expense, gain/loss on disposal |
| Stock | IM | 1300 Inventory control, COGS |

**GL's tag-derived ageing and per-party routes are therefore not extended**, and are planned for retirement as screen sources: the AP and AR ageing routes (`accounts-payable-aging`, `accounts-receivable-aging`), the supplier and customer balances routes, and the ageing buckets of `receivables-payables-summary`. CM states that the EA dashboard "Money owed" tile and WEB read them today; I have not verified every consumer. Cut-over, consumer-first:
1. POP and SOP serve their own ageing and per-party balances.
2. GL, EA and WEB agree a cut-over date; EA's tile and WEB's screens move to POP/SOP for ageing and per-party detail, and to GL's control-account balances for the totals.
3. GL marks the routes deprecated (documented, still served), removes them only after no caller remains.
4. The `CUSTOMER` and `VENDOR` tags on journal lines stay as audit data; no new logic on them.

This does not touch the per-line account work (P0).

---

## 7. Decisions for Femi

- **D1 (sequencing).** Flip the contexts to Suspense with step 2 (recommended: after POP and SOP can send accounts) or immediately? Immediately sends all new purchases and sales to Suspense until they do.
- **D2 (sales revenue source).** Add a `revenueAccountId` to IM items (goods and services) as the default source for a sale line, with the line overridable at order time? I recommend yes.
- **D3 (stock purchases).** A POP line linked to a STOCK item posts to Inventory through IM's receipt, not to an expense account. Confirm: per-line account applies only to service and expense lines; stock lines are out of scope here (they belong to seam A / GRNI).
- **D4 (credit note target).** May a supplier credit note line credit an expense account (the original rent account) instead of 4920 Discounts Received? 4920 stays the default either way.
- **D5 (settlement account).** Payments and collections always use Cash 1000 today. Add an optional per-transaction `settlementAccountId` (a cash or bank book) in the same build, or separately?

## 8. Build order and estimate

Branch from GL master, tests first, each step its own tip to CM:
1. Validation rule and shared resolver (`ResolveLineAccount`): tests 4 and 6. About half a day.
2. Record-obligation per-line, tags H, tests 1 to 3, 5. About one day.
3. Record-sale mirror, tests 7. Half a day.
4. Credit note and sales return per-line, tests 8. Half a day.
5. Account list `?type` and `?usableFor`, route tests. Half a day.
6. Contract fixtures (fish-contracts PR), playbook and test-plan rows. Half a day.
7. Step 2: the context flip with the POP/SOP release. Half a day plus the consumers' own work.

About four days of GL work for step 1, plus the consumers'. Needs: CM review of this note (HIGH), Femi's D1 to D5, a coordination row (claimed in `docs/GL_POP_IM_SOP_Coordination.md`).

## 9. Decisions taken (CM HIGH review, 2026-10-18, relaying Femi)

- **D1 yes:** step 1 additive (no behaviour change); step 2, the context flip to Suspense, is released **together with** the POP and SOP senders, coordinated by CM. GL tells CM when step 1 is live.
- **D2 yes:** IM items get an optional `revenueAccountId` (services and stock goods). CM tells IM.
- **D3 agreed:** stock lines are out of scope (seam A).
- **D4 not now:** supplier credit notes keep the single 4920 Discounts Received; "credit the original expense account" is parked for Femi with seam A. Section 2.5's per-line credit-note account is therefore **not** in step 1.
- **D5 parked:** settlement account (Femi: 1000 is always the Cash Book; bank accounts as cash books are a separate decision).
- **Added to step 1:** the missing `VAT_DIRECTION=INPUT` tag on record-obligation input VAT lines (and `OUTPUT` on sales VAT lines); additive.
- **Step 1 therefore contains:** per-line `accountId` on record-obligation and record-sale, the shared validation, the Suspense fallback when a request sends no account at all, the direction tags, the filtered account list (`?type`, `?usableFor`), contract fixtures. Contexts are unchanged until step 2.
