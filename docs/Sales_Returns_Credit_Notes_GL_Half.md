# Sales returns and credit notes: GL's half (SPUTO)

**From:** General Ledger (GL) session. **Date:** 2026-10-11. **Status:** DRAFT for Femi's approval as a Playbook part. Docs only: **no GL code until Femi approves** (CM, 2026-10-11). **Requested by:** CM, from SOP's sitting report. **Written against:** GL master `f47b4c8` (plus `7298fe5`) (`RecordSalesReturnUseCase`, `RecordSalesReturnRoutes`, `ComputeSalesPostingContextUseCase`, `ComputeVatReturnUseCase`/`VatReturn`, `ChartOfAccountsTemplate`). SOP drafts the use cases and SRS for its own side; IM covers the stock-value side. Where this note needs an answer from either, it says so.

Form: Femi's SPUTO (Scope, Plan/SRS, Use cases, Tasks, Order).

---

## 1. Scope (S)

**The defect, verified in the code.** `POST /sales/record-sales-return` (`RecordSalesReturnUseCase`) posts **one amount**: `Dr Sales Returns / Cr Accounts Receivable`, nothing else. A credit note on a VATable sale therefore reduces what the customer owes by the **gross** amount but reduces revenue by the **same gross** amount, and **never reverses the output VAT** that the original sale credited to the VAT control account (2150). Result: revenue is understated by the VAT, output VAT is overstated by the same amount, and the VAT return is wrong. It is an accounting correctness defect, not a missing feature.

Four more findings in the same area:

1. **There is no Sales Returns account to post to.** No chart template seeds one and `sales-posting-context` returns none, so the caller chooses an account it cannot discover (the route takes `salesReturnsAccountId` from the request; the use case only checks the account belongs to the Company).
2. **Nothing validates the three accounts' kinds.** The AR account, the returns account and (once added) the VAT account are looked up by id and company only. A wrong id posts silently.
3. **The route is already idempotent-capable** (`respondIdempotently`), but SOP sends no `Idempotency-Key`, and the helper's simultaneous-duplicate gap is open (`docs/GL_Idempotency_Claim_First_Design_Note.md`).
4. **Period and AR account are chosen by the caller**; `sales-posting-context` returns them, but it has no returns or credit-note view of the world.

**A fifth finding, new, and the reason a posting change alone is not enough: `VatReturn` classifies VAT by the SIDE of the line.** `VatReturn.of` counts every CREDIT to the VAT control account as output VAT and every DEBIT as **input** VAT. A correct credit-note reversal is a debit to the VAT control account, so it would be reported as *input* VAT: the net figure would be right but **both gross figures would be overstated** (output by the reversed VAT, input by the same). Return forms report credit notes issued as a reduction of VAT on sales (Ireland's T1), not as VAT on purchases (T2). The VAT return must learn the direction of a line, not infer it from its side. This applies equally to a return **to** a supplier (Returns Outwards: a credit to the VAT control account would count as output); that mirror is listed in section 6, not built here.

**What GL owns:** the Sales Returns account, a credit-note posting shape that reverses VAT per category, a read route that gives SOP everything it needs to post a credit note, the VAT return's direction rule, account-kind validation, retry safety and the migration path off today's single-amount shape.

**Out of scope here:** the stock-value side of a resaleable return (IM, `docs/Returns_Inwards_Requirements_Specification.md` section 3.5, its Dr Inventory leg), which credit-note lines SOP decides to issue and what the person types (SOP), refunds of cash to a customer (that is a payment, not a return), Scrap and Repairable dispositions (still open in `docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`), multi-currency credit notes (IAS 21 design).

## 2. Plan / SRS (P)

### 2.1 Decisions proposed (for Femi)

| # | Decision | GL's proposal |
|---|---|---|
| D-SR1 | **Posting shape: per-line VAT categories, GL computes the VAT** (the same as `record-sale`), rather than GL reversing a named original sale. | Per-line. GL does not know SOP's invoice-to-entry mapping and a partial return would need allocation logic that belongs to SOP; SOP already holds each credit-note line's net amount and category from the original invoice. |
| D-SR2 | **Rate date:** VAT is computed at the rate in force on the **original supply date**, not the credit-note date. | An optional `originalSupplyDate` on the request (default: the credit-note date). Matters across a rate change (Ireland's 9% from 1 July 2026): a credit note issued in August for a June sale must reverse VAT at the June rate. |
| D-SR3 | **Sales Returns account `4900`, REVENUE type (contra revenue, normal debit)**, seeded in every business template; older Companies get it from the existing standard-accounts route. | Yes. (Code 4900 is free; the lowest-coded REVENUE account stays 4000, so `sales-posting-context`'s existing choice of revenue account does not change.) |
| D-SR4 | **VAT direction on the line:** a new dimension `VAT_DIRECTION` (`OUTPUT` / `INPUT`) tagged on VAT control lines of new credit-note postings; `VatReturn` classifies tagged lines by tag, untagged lines by side exactly as today. | Yes. Nothing already posted changes meaning. |
| D-SR5 | **Retire the single-amount shape** after SOP adopts the lines shape: log-first (a counted warning on each legacy call), then refuse, on the cash-book policy pattern (`FISH_SALES_RETURN_LEGACY_MODE`, only the word `enforce` enforces). | Yes. |
| D-SR7 | **Scholarships, waivers and price reductions are discounts, treated as accountants treat business discounts (Femi, 2026-10-13): two accounts, `Discounts Given` (`4910`, what the business allows its customers) and `Discounts Received` (`4920`, what it gets from its suppliers).** A waiver or scholarship after invoicing is a credit note of kind DISCOUNT that debits Discounts Given, not Sales Returns. See section 2.4. | **Decided (Femi).** The codes, the VAT treatment and the exact legs are GL's proposal in 2.4. |
| D-SR6 | **Idempotency-Key required** for the lines shape (400 `idempotency_key_required` without it). | Yes: a credit note is money; SOP has a natural key (`credit-note:{creditNoteId}`). |

### 2.2 Requirements

**Accounts**
- **FR-SR01 (M)** Every business chart template seeds `4900 Sales Returns` (REVENUE). Individual charts do not.
- **FR-SR02 (M)** `4900` is added to `ModuleOwnedAccounts` with token `SALES_COLLECTION`, so the cash book refuses it as a counter-account.
- **FR-SR03 (M)** `POST /companies/{id}/standard-accounts` adds `4900` to an older Company (it iterates the template; no change to the use case); a Company with a different-type account at `4900` gets the existing **conflict** report and nothing is changed.
- **FR-SR04 (M)** The account is found **by code and type** (`4900` REVENUE).

**Finding what to post to (strict-decoder safe)**
- **FR-SR10 (M)** A **new** read route `GET /companies/{companyId}/credit-note-posting-context` returns `{ periodId, arControlAccountId, salesReturnsAccountId, vatControlAccountId, currency }`, all required. It answers 404 `company_not_found`, 409 `no_open_period`, 409 `ar_control_account_not_configured`, 409 `sales_returns_account_not_configured`, 409 `vat_control_account_not_configured` (the codes mirror `sales-posting-context`'s), never nulls.
- **FR-SR11 (M)** Full tenancy sequence as every Company route (`resolveTenantForCompany`, `verifyClaimedTenant`, `authorizeTenantForRead`); added to the **sop** allow-list in the same change; the allow-list inventory test updated.
- **FR-SR12 (M)** `sales-posting-context` is **not changed.** SOP decodes GL responses strictly; any new key, even nullable, breaks SOP until SOP declares it, and this is the same ordering trap as the GRNI note. A new route has no ordering coupling.

**`record-sales-return`, lines shape**
- **FR-SR20 (M)** The request gains optional `lines: [{ netAmount, vatCategory }]` and optional `originalSupplyDate`. When `lines` is present the shape is **new**; the single `amount` must then be absent (400 `bad_request` if both are sent). GL decodes its own requests, so old callers are unaffected.
- **FR-SR21 (M)** Posting for the lines shape, one entry: **Dr Sales Returns** (sum of nets), **Dr VAT control** per category present (the VAT computed from each category's net with the schedule's rate as of `originalSupplyDate`, as `RecordSaleUseCase` does for a sale; each VAT line tagged `VAT_CATEGORY` and `VAT_DIRECTION=OUTPUT`), **Cr AR control** (gross) tagged with the customer. Balanced to the cent for any mix of categories.
- **FR-SR22 (M)** A category with no VAT (EXEMPT, ZERO) posts no VAT line, exactly as in `record-sale`; an unsupported category is 400 `vat_category_not_supported` before anything is written.
- **FR-SR23 (M)** Account kinds are checked: the returns account must be REVENUE, the AR account the Company's AR control (ASSET, code 1100), the VAT account the Company's VAT control (LIABILITY, code 2150); otherwise 400 `account_not_allowed` naming the role (never confirming another Company's account: an id from another Company is still 404 as today).
- **FR-SR24 (M)** The response (`journalEntryId`, `status`) is **unchanged**: no consumer decoding change for the POST.
- **FR-SR25 (M)** The single-`amount` shape keeps working unchanged until D-SR5's switch: Dr Sales Returns / Cr AR for the amount, **no VAT**, with a counted log-first warning `sales_return_without_vat` on each use; once enforced it is refused with 409 `sales_return_vat_required`.

**VAT return**
- **FR-SR30 (M)** A new `DimensionType.VAT_DIRECTION` (values `OUTPUT`, `INPUT`). `VatReturn.of` treats a VAT control line tagged `OUTPUT` as output VAT (a credit adds, a debit subtracts) and one tagged `INPUT` as input VAT (a debit adds, a credit subtracts); **an untagged line is classified by side exactly as today**, so every entry already posted keeps its meaning.
- **FR-SR31 (M)** The category breakdown (signed, per category) is unchanged in meaning: a credit-note debit already reduces its category.
- **FR-SR32 (M)** `record-sale` and `record-supplier-obligation` need no change (their untagged lines are classified correctly by side); tagging them is optional and deferred.

**Idempotency and retry**
- **FR-SR40 (M)** A retry with the same key and body returns the original entry and posts nothing; a refusal does not spend the key (`7298fe5`); a key reused with a different body after a success is 422.
- **FR-SR41 (M)** The simultaneous-duplicate case is closed by whichever mechanism Femi approves in the claim-first note: option C (claim and post in one transaction, proven by spike S1) for every route, or, as the fallback for this single-entry route, an entry id derived from (tenant, endpoint, key) with `insertIfAbsent` (the cash book's pattern). This note does not pick; it requires the property.

**Compatibility**
- **FR-SR50 (M)** Additive only: no existing field, status code or response shape changes; the legacy shape runs until the policy is enforced.
- **FR-SR51 (M)** T15 isolation tests for the new route and the changed route (other Tenant 403, other service 403, other Company's account 404, not 200).

### 2.4 Discounts Given and Discounts Received (Femi, 2026-10-13)

Femi's direction: a scholarship or waiver "should be treated as accountants treat business discounts: Discounts Given, Discounts Received". It replaces this note's earlier suggestion of folding waivers into the Sales Returns account. How accountants treat them, and what that means in GL:

| Case | Treatment | GL |
|---|---|---|
| **Trade discount known when the invoice is made** (a sibling discount, a scholarship granted at billing) | Deducted on the invoice; only the net is recorded as revenue. | No new posting: SOP sends the smaller net amount on the line. Optional later: show the gross fee and the discount as two lines (Dr Discounts Given) so reports show what was waived; not needed for correctness. |
| **Waiver, scholarship or price reduction granted AFTER invoicing** | A credit note that reduces what the customer owes and is recorded as a discount, not a return. | `record-sales-return` gains a `kind` (`RETURN` default, or `DISCOUNT`): the lines shape of FR-SR21 with **Dr Discounts Given** instead of Dr Sales Returns, the VAT reversed per category as for a return, Cr Receivable. |
| **Settlement (early-payment) discount taken at collection** | Cash received is less than the invoice; the difference is Discounts Given. | `record-collection` gains an optional `discountAmount`: Dr Cash (received) / Dr Discounts Given (discount) / Cr Receivable (received + discount). |
| **Discount received from a supplier** (settlement discount, price allowance) | Payment is less than the invoice; the difference is Discounts Received (other income, or a reduction of cost, by the accountant's rule). | `record-payment` gains an optional `discountAmount`: Dr Payable (paid + discount) / Cr Cash (paid) / Cr Discounts Received (discount); a supplier credit note of kind DISCOUNT does the same after the invoice. The VAT leg uses the same direction tag (`INPUT`) as the Returns Outwards mirror. |

Requirements:
- **FR-SR60 (M)** Every business chart template seeds `4910 Discounts Given` (REVENUE type, contra revenue, normal debit) and `4920 Discounts Received` (REVENUE type, normal credit; presented as other income); older Companies get both through standard-accounts, with the existing conflict report.
- **FR-SR61 (M)** Both are added to `ModuleOwnedAccounts` (tokens `SALES_COLLECTION` and `PURCHASE_PAYMENT`) so the cash book refuses them as a counter-account.
- **FR-SR62 (M)** `credit-note-posting-context` (FR-SR10) also returns `discountsGivenAccountId`, required and never null, with the same 409 when missing, so SOP finds the account without a guess. `Discounts Received` is returned by the purchase-side read route when POP needs it (a separate request, not built here).
- **FR-SR63 (M)** A DISCOUNT credit note may exceed the customer's open balance (it then leaves a credit balance), exactly as a return may: no balance check is added; the VAT reversal is the same arithmetic as for a return.
- **FR-SR64 (S)** The reporting views: Discounts Given appears under Revenue as a deduction (net sales), Discounts Received under other income, so the trading profit and loss and the gross margin read correctly; checked against `ComputeTradingProfitAndLossUseCase` before build.

For the Education Runtime (+ER Education requests Q3 and Q4): a scholarship or waiver is Discounts Given; a sibling discount is a trade discount (netted on the invoice); a school-funded scholarship may later be tracked per scholarship by a dimension without a new account. A scholarship **paid by a sponsor** is not a discount and does not change the customer (Femi, 2026-10-13: a third party paying an invoice does not change the legal status of the customer or guardian): the guardian stays the customer, the invoice and the receivable stay on the guardian, and the sponsor is the **payer** on the collection. In GL that is an ordinary `record-collection` against the guardian (Dr Cash / Cr Receivable tagged with the guardian). **What GL needs to carry:** nothing new is required for correctness. The payer is data in SOP and the Education Runtime (the collection record names the payer). For a person reading the books, the payer can go in the collection's existing `description` (for example "Fees paid by <sponsor> for <guardian>"), which `record-collection` already accepts and the cash book already shows. A queryable payer (a `PAYER` dimension on the cash line, so GL could report collections by payer) is not built and is not needed for any current requirement; it is a small additive change if a report ever needs it, decided then, not now.

**Open for the accountant (not blocking the account split):** the VAT effect of a settlement discount (some jurisdictions reduce the VAT only when the discount is taken; education fees are usually exempt, so it rarely arises for a school), and whether Discounts Received should be other income or a deduction from purchases in the Company's reporting.

### 2.3 Open questions (answers needed)

- **Q-SR1 (SOP):** SOP's credit note today carries **one amount typed by the person** (`SOP_Playbook_Draft.md`). The lines shape needs the net and category per line. Where does SOP get them: from the original invoice's lines (proportionally, for a partial return)? Or should GL also accept `grossAmount` + one `vatCategory` and back out the VAT (net = gross / (1 + rate))? The second is easier for SOP and lossy for a mixed-rate invoice. Default here: lines only.
- **Q-SR2 (SOP/Femi):** rounding. Reversing a partial return computes VAT on the credit-note net, so it can differ from the original VAT by a cent. Accept (default) or let SOP pass the exact VAT amount per line to be posted as given?
- **Q-SR3 (IM):** the stock leg (`Dr Inventory / Cr Cost of Sales` at cost, by the return's disposition) needs IM's receipt against a return (the generalized goods-receipt change). GL's posting for the credit note is independent of it; no ordering dependency. Confirm.

## 3. Use cases (U)

**UC-SR1: SOP issues a credit note on a VATable sale (the main case).**
SOP reads `GET /companies/{id}/credit-note-posting-context`, then posts `record-sales-return` with `Idempotency-Key: credit-note:{creditNoteId}`, one line net 1,000.00 category STANDARD (23%), `originalSupplyDate` the invoice date. Result, one entry: Dr Sales Returns 1,000.00, Dr VAT control 230.00 (tagged STANDARD, OUTPUT), Cr AR 1,230.00 (tagged with the customer). Customer's balance falls by 1,230.00; revenue falls by 1,000.00; output VAT falls by 230.00.

**UC-SR2: Mixed-rate credit note.** Two lines, STANDARD 1,000.00 and REDUCED 400.00. One entry, one Dr VAT line per category, one Cr AR for the gross.

**UC-SR3: Exempt or zero-rated return.** Only the Sales Returns debit and the AR credit; no VAT line.

**UC-SR4: A credit note after a rate change.** Sale in June at 13.5%, credit note in August when the rate is 9%: with `originalSupplyDate` in June, VAT is reversed at 13.5%, so the reversal equals what the sale charged.

**UC-SR5: A retry.** The first call timed out. SOP sends the same key and body: the same entry id comes back, nothing is posted twice. A different body under the same key: 422.

**UC-SR6: The Company has no Sales Returns account (older chart).** The context route answers 409 `sales_returns_account_not_configured`; the owner runs standard-accounts; SOP retries.

**UC-SR7: The VAT return after a credit note.** For the filing period, output VAT is reduced by the reversed VAT (T1 net of credit notes); input VAT is not touched; the net figure is the same as before, and the gross output and input figures now match the forms.

**UC-SR8: SOP still sends the old single amount.** It posts as today, no VAT reversal, with a counted warning; after the switch it is refused with 409 and SOP must send lines.

## 4. Tasks (T)

| # | Task | Size | Notes |
|---|---|---|---|
| S1 | Chart template: `4900 Sales Returns` (business templates), constants, `ModuleOwnedAccounts` (token SALES_COLLECTION), standard-accounts test (adds it, reports a type conflict) | 0.5 d | red tests first |
| S2 | New `GET /companies/{id}/credit-note-posting-context` (use case, route, DTO, 404/409 codes), sop allow-list and inventory test, T15 tests | 0.75 d | |
| S3 | `DimensionType.VAT_DIRECTION`; `VatReturn.of` classifies tagged lines by tag, untagged by side; tests: credit-note reversal reduces output not input; old entries unchanged; breakdown unchanged | 0.75 d | checks every reader of dimensions (journal line DTOs expose them as strings) |
| S4 | `record-sales-return` lines shape: request fields, VAT computation per category with the rate asOf `originalSupplyDate`, grouping, tags, account-kind validation (`account_not_allowed`), `idempotency_key_required`; balance property tests across category mixes; regression of the legacy shape | 1.25 d | |
| S5 | Legacy-shape policy (`sales_return_without_vat` warning, `FISH_SALES_RETURN_LEGACY_MODE`, enforce -> 409), same pattern as `CashBookPolicies` | 0.5 d | log-first |
| S6 | Retry safety for the route: tests (replay, refusal-then-fix, different body) now; simultaneous-duplicate closure from the claim-first note, 0.25 d to 0.5 d on this route once Femi approves it | 0.5 d | |
| S8 | Discounts (D-SR7, 2.4): accounts `4910`/`4920` in the templates, module-owned tokens, standard-accounts test; `kind` on `record-sales-return` (DISCOUNT debits Discounts Given); `discountAmount` on `record-collection` and `record-payment`; `discountsGivenAccountId` in the credit-note context; trading profit and loss check; balance and VAT property tests | 1.5 d | extends S1, S2, S4; the supplier side waits for POP's request |
| S7 | Docs and handoff: GL playbook sheet, the exact response and error codes to SOP and WEB before anything is enforced | 0.25 d | |

GL total about **6 days** after approval (4.5 plus the discounts, S8), in the order below. SOP's side (issue per-line credit notes, call the new context route, send the key) and IM's stock leg are their own estimates.

## 5. Order (O): foundations first

1. **Foundation, done:** a refusal does not spend the key (`7298fe5`).
2. **Foundation, pending Femi's approval of the claim-first note:** the simultaneous-duplicate closure (S6's last part). Credit notes are money, so this precedes enforcement of the new shape, not its introduction (sequential retry is already safe).
3. **Femi approves this note** (D-SR1 to D-SR6; D-SR7 is already decided by Femi, 2026-10-13, and only its legs need his approval with the rest).
4. **GL, in this order:** S1 (account) then S3 (the VAT return direction, so no credit note can ever be posted into a return that misreads it) then S2 (context route) then S4 (the posting) then S5, S6, S7. S3 before S4 is deliberate: shipping the VAT reversal first would make the VAT return misreport input VAT until S3 lands.
5. **SOP, after GL deploys:** call the context route, issue per-line credit notes, send `Idempotency-Key`, stop sending the single amount. Then GL enables the legacy policy to log, and later to enforce, with SOP told the codes first.
6. **Cutover and existing data:** credit notes already posted without VAT stay as they are (pre-live data, standing rule). Their output VAT is overstated; an accountant can post a correcting journal for any real Company, and the VAT return for a period containing one is wrong until corrected. GL cannot repair them and does not try.

## 6. Out of this note, said plainly

- **Returns Outwards (purchase side)** has the mirror defect for VAT *if and when* its AP side is posted with VAT: a credit to the VAT control account would be read as output VAT. S3's `VAT_DIRECTION=INPUT` is the same fix. Today POP's return posting is inventory-side only (`docs/Purchase_Inventory_Sales_Cycle_And_Reversals_Scoping.md`); this is recorded so the AP and VAT side of a return outwards is not designed without it.
- Refunds to the customer, the IM stock leg, Scrap and Repairable dispositions and foreign-currency credit notes are separate pieces.
