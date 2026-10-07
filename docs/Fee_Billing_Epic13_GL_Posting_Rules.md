# Epic 13: GL half. Posting rules, VAT decision, chart-of-accounts mapping (SPUTO: P and T)

**Status:** draft for review, 2026-10-07. Written by the GL session as its half of `docs/Fee_Billing_Epic13_SPUTO_Scope.md` (the **S**; section 6 assigns GL the posting rules, the VAT exempt path, the chart-of-accounts mapping and any GL change). **Docs only: nothing is built, and no code is started** until CM's dependency order exists and Femi has answered the section 9 decisions. Everything about GL below was read from the code on `origin/master` (GL `:97`, 2026-10-07); section 11 lists the evidence. Where a statement is a recommendation, not a fact, it says so.

**Labels:** **FACT** = read from code or a source doc. **RECOMMENDED** = GL's proposal, not agreed. **OPEN** = someone else's decision (named).

---

## 1. Answers CM asked for first

### 1.1 VAT: exempt-only path, or seed and verify every country first? (RECOMMENDED: a governed exempt-only path)

Build a narrow, governed exempt-only path. Do **not** make every country wait for a verified schedule.

- **Why it is safe.** An all-EXEMPT sale needs no rate. EXEMPT has no rate by definition (`VatRateSchedule` rejects it as a key and always answers `supports(EXEMPT)`), and an exempt line posts no VAT line. So GL cannot post a wrong VAT amount. The only risk is the classification itself ("this fee is exempt in this country"), which is a legal fact about the jurisdiction, not something GL computes, and which the schedule path equally trusts the caller for.
- **Why it must be governed.** It is opt-in per jurisdiction, stored as data, with the same `verified` gate as `vat_rates`: a tiny table `vat_exempt_only(jurisdiction, verified)`, default off, flipped to verified by CM only after Femi confirms against a primary tax source that the fee category is exempt there. The append-only audit trail already on the backlog (required before any VAT row is flipped) must cover this table too.
- **Why it is narrow.** Every line of the sale must be EXEMPT, or the sale answers 409 `no_vat_rate_schedule` exactly as today. ZERO_RATED and any taxable line still need a verified schedule. So it unblocks tuition, boarding, levies and pass-through fees, but **not goods**: uniforms and books are normally standard-rated, and one taxable line refuses the whole invoice (a sale posts atomically). Consequence for SOP and ER: bill taxable goods on a separate invoice, or keep those billing items disabled in a country until its schedule is verified.
- **Nigeria:** `docs/NG/NG_Tax_And_Currency_Settings.md` lists education services as VAT-exempt under NTA 2025. That is a candidate, not a confirmation: **OPEN, Femi** to confirm against a primary source before CM flips it.
- **Sierra Leone:** `docs/SL/SL_Tax_And_Currency_Settings.md` found a single 15% GST and **no exemption list at all**. Whether education is exempt there is genuinely **OPEN** and needs a primary-source check (the same caveat that keeps SL's rate row unverified). GL will not assume it.
- **Alternative considered (seed and verify first).** Cleaner in principle, and still needed for any taxable item, but it blocks the arrowhead market on tax research for categories (standard rate, zero rate) a fee-only school does not use. Do it for Nigeria anyway (7.5% standard, 0% food and basics), but not as a precondition for exempt fees.
- **Size:** small (one migration, one route change; the posting use case already accepts an exempt-only schedule). About one day with tests, shippable before the larger items.

### 1.2 Do payment channels (cash, transfer, wallet) map to a bank or clearing account? (FACT: yes; but the accounts do not exist yet)

`record-collection` debits **any** settlement account the caller names (Dr settlement, Cr Accounts Receivable) and does not type-check it, so a channel maps to an account cleanly: cash to Cash, bank transfer to a bank account, mobile money and gateway/POS to a **clearing** account that is later settled to the bank. What is missing is the accounts: the standard templates contain only Cash (1000). There is no bank account, no clearing account, no deferred income, no pass-through liability, no parent-advance account, no scholarship or bad-debt account, and one revenue account. See section 4.

---

## 2. What GL can post today, row by row (ER spec section 2.7)

| Spec row | Posts today? | How, and what is missing |
|---|---|---|
| Tuition or boarding invoice (Dr Fees receivable, Cr revenue) | **Partly** | `record-sale` posts Dr AR gross, Cr revenue net, Cr VAT per category. But it takes **one** revenue account for the whole invoice (`revenueAccountId` on the request); an invoice with tuition, boarding and a levy needs one credit account per line. |
| Billed before term (Cr deferred income) | **No** | No deferred-income account; no release posting. See G4. |
| Levies, designated fund | **Partly** | Same per-line limit; fund treatment is a policy decision (D3). GL has no fund accounting. |
| PTA / exam fees on behalf (Cr liability) | **No** | Needs per-line credit to a LIABILITY account, plus the liability accounts. The backlog row guessed GL's "CoA-mapping mechanism" might already express this: it does not. GL has no mapping mechanism at all; accounts are found by hard-coded code conventions (1100, 1000, 2150, lowest revenue code). |
| Books or uniform sales | **Yes, if the country has a verified schedule** | Taxable goods need rates. |
| Payment by transfer, cash, POS | **Yes** | `record-collection` to the right settlement account. |
| Gateway or mobile money, then settlement | **Half** | Collection into a clearing account works once the account exists. The settlement (Dr Bank, Dr Charges, Cr Clearing) is a generic journal, which SOP's service account can post through `POST /journal-entries` today (Idempotency-Key honoured). |
| Scholarship, discount, waiver | **Yes, without VAT** | `record-sales-return` debits whatever account the caller names (Dr account, Cr AR). A scholarship or discount account works. It does **not** reverse VAT, so it is right for exempt fees only. |
| Overpayment or advance (Cr customer advances) | **No** | `record-collection` credits AR only. An overpayment becomes a credit balance on AR, with no advance account and no split. |
| Refund (Dr advances or AR, Cr bank) | **No thin interface** | Generic journal only. |
| Bad-debt write-off | **No thin interface** | Generic journal only. |
| Void a receipt or cancel an invoice | **No route** | `ReverseJournalEntryUseCase` exists but **no HTTP route exposes it**. |

---

## 3. Requirements for the GL half (P)

IDs are new, `FR-GLFEE-nn`, so the other halves can cite them.

| ID | Requirement | Type |
|---|---|---|
| FR-GLFEE-01 | A sale in a jurisdiction with no verified VAT rows is accepted **only if every line is EXEMPT and the jurisdiction is flagged exempt-only (verified)**; otherwise it is refused as today. Never a computed or guessed rate. | Must |
| FR-GLFEE-02 | One invoice posts as **one** journal entry (Dr AR gross, Cr one account per line), so a billing run is one idempotent call per invoice and the ledger stays traceable per invoice. | Must |
| FR-GLFEE-03 | Each sale line may name its own credit account, which must belong to the Company and be REVENUE or LIABILITY (revenue, deferred income, pass-through). Absent means the request's revenue account, so every existing caller is unchanged. | Must |
| FR-GLFEE-04 | A school's chart of accounts can be extended with a versioned **account pack** idempotently (add what is missing by code, never change or delete), so existing Companies and new ones converge on the same accounts. | Must |
| FR-GLFEE-05 | Fee items, payment channels and waiver types resolve to GL accounts through a **role mapping** that is data, versioned per Company, readable by SOP and editable by an authorised finance user. (FIN-INT-015) | Should (RECOMMENDED over per-item account ids; see G6) |
| FR-GLFEE-06 | A collection can split an overpayment: the part applied to receivables credits AR, the excess credits a parent-advance liability, in one entry. | Should |
| FR-GLFEE-07 | Waivers, discounts, scholarships and credit notes post to a configured debit account (scholarship expense or discount); a taxable credit note reverses VAT. | Must (exempt now, taxable later) |
| FR-GLFEE-08 | A refund posts Dr parent-advance or AR, Cr the settlement account, carrying the approver reference. | Should |
| FR-GLFEE-09 | If revenue is recognised over the term, a thin posting releases deferred income to revenue (one call = one release, the same discipline as `Prepayment`/`FixedAsset`). | Must **if** D1 chooses deferral |
| FR-GLFEE-10 | A posted entry can be reversed over HTTP (receipt void, invoice cancellation), with the closed-period guard `ReverseJournalEntryUseCase` already enforces. | Must |
| FR-GLFEE-11 | Every posting from SOP carries a traceable reference to the SOP document (invoice, receipt number) in the entry's description, and SOP stores the returned journal entry id, so the daily reconciliation (FIN-INT-012) can match both ways. | Must |
| FR-GLFEE-12 | Changes to VAT rows, the exempt-only flag and the account-role mapping are recorded in an **append-only audit trail** (who, when, old, new, source cited) before any country is switched on. | Must |
| NFR-GLFEE-01 | All new fields are additive, with no defaults on the wire. Release order is the one already used: consumers with strict DTOs (SOP, WEB) deploy tolerant first, GL second. | Must |
| NFR-GLFEE-02 | Billing-run volume: a school with 1,000 students means about 1,000 `record-sale` calls a term. Verify throughput and idempotent retry on that size before pilot; a batch endpoint only if measurement shows it is needed. | Should |

---

## 4. Chart-of-accounts mapping

### 4.1 Account pack `SCHOOL_FEES` v1 (RECOMMENDED; codes chosen to avoid every code the templates use today: 1000, 1100, 1200, 2000, 2100, 2150, 2200, 2300, 3000-3910, 4000, 4100, 5000-5400)

| Code | Account | Type | Purpose |
|---|---|---|---|
| 1010 | Bank, operating | Asset, current | Bank transfers, deposits; settlement target. More banks add 1011, 1012... |
| 1110 | Mobile money clearing | Asset, current | Wallet collections until settled to the bank |
| 1120 | Payment gateway clearing | Asset, current | Card and gateway collections until settled |
| 1130 | POS clearing | Asset, current | POS collections until settled |
| 2400 | Deferred fee income | Liability, current | Fees billed before the term (only if D1 chooses deferral) |
| 2410 | PTA collections payable | Liability, current | Pass-through, not revenue |
| 2420 | Exam fees payable | Liability, current | Pass-through, cleared on remittance to the exam body |
| 2430 | Parent advances and credit balances | Liability, current | Overpayments and advances, applied to the next invoice or refunded |
| 2440 | Other third-party collections payable | Liability, current | Any other fee collected on behalf of a third party |
| 4010 | Tuition fees | Revenue | |
| 4020 | Boarding fees | Revenue | Only for boarding schools |
| 4030 | Development and other levies | Revenue | Designated-fund treatment per school (D3) |
| 4040 | Books and uniform sales | Revenue | Taxable goods in most countries |
| 4050 | Government subvention and grant income | Revenue | Government-funded items (ER-FEE-014), kept apart from parent-paid fees |
| 4090 | Other fee income | Revenue | |
| 5500 | Scholarships and bursaries | Expense | Waiver, scholarship (see D2 on contra-revenue) |
| 5510 | Fee discounts and waivers | Expense | |
| 5520 | Bad debt expense | Expense | Write-offs |
| 5530 | Payment gateway and bank charges | Expense | Settlement charges |

The pack **adds** to the standard template; it never changes 1000, 1100, 4000 and the rest. `CreateAccountUseCase` already returns `DuplicateCode`, so an idempotent apply by code is natural.

### 4.2 Mapping per school type

The accounts are the same across school types; what differs is policy. **+ER Education** owns the taxonomy (this is GL's reading of it); **Femi or finance signs off the mapping** (scope doc, section 7).

| School type (GL ClientType) | Revenue accounts | Scholarships | Surplus | Notes |
|---|---|---|---|---|
| Private, for profit (COMPANY_LIMITED; sole trader and partnership alike) | 4010, 4020, 4030, 4040, 4090 | 5500 / 5510 expense | Retained earnings (3100) | Standard case |
| Non-profit or mission (NON_PROFIT) | Same pack. The template's 4000 "Donations income" and 4100 "Grants income" stay for gifts and grants, not fees | Expense; a designated levy may need restricted treatment | Unrestricted (3000) or restricted (3100) net assets | GL has no fund accounting: a restricted levy is revenue 4030 in v1, with a manual year-end transfer (D3) |
| Government-aided or subvention-funded | Pack, plus 4050 for the government-funded items, billed to the ministry or agency as its own payer so a receivable exists | Often none | As above | Free-school items recorded apart from parent-paid items (ER-FEE-014) |
| Multi-campus group | One Company per legal school (FIN-INT-001), campus as the `LOCATION` dimension | | | **GL has no consolidation**; a group view needs a separate piece of work |

**Not accounts:** level, stream, house and day or boarding status. Those belong in dimensions on the journal lines (`DEPARTMENT` for level, `LOCATION` for campus, `PRODUCT_LINE` or `ITEM` for the fee item), which exist today. The **student** is deliberately not a ledger dimension: the payer is (`CUSTOMER`), and the per-student balance lives in SOP, which is the source of truth for billing accounts. GL records financial effect, not operational detail.

### 4.3 Posting rules (the worked examples SOP and ER can test against)

Amounts illustrative, currency one per Company, all fees EXEMPT.

| Event | Entry |
|---|---|
| Invoice: tuition 100,000, boarding 40,000, PTA 5,000 | Dr 1100 AR 145,000; Cr 4010 100,000; Cr 4020 40,000; Cr 2410 5,000. No VAT line. **One** entry for the invoice. |
| Same, billed before term with deferral (D1) | Cr 2400 for the term fees instead of 4010/4020; then each period Dr 2400, Cr 4010 or 4020 (G4) |
| Bank transfer | Dr 1010 Bank; Cr 1100 AR |
| Mobile money | Dr 1110 clearing; Cr 1100 AR. On settlement: Dr 1010 Bank, Dr 5530 charges, Cr 1110 (generic journal in v1) |
| Cash or POS | Dr 1000 Cash or 1130 POS clearing; Cr 1100 AR |
| Payment of 10,000 against a 5,000 invoice (overpayment) | Dr 1010 Bank 10,000; Cr 1100 AR 5,000; Cr 2430 Parent advances 5,000 (G5), one entry |
| Scholarship or waiver | Dr 5500 or 5510; Cr 1100 AR (works today via `record-sales-return`) |
| Refund | Dr 2430 or 1100; Cr 1010 (G7) |
| Remit exam fees to the body | Dr 2420; Cr 1010 (generic journal) |
| Write-off | Dr 5520; Cr 1100 |
| Void a receipt | Reverse the collection entry (G8); never delete |

---

## 5. Gaps and proposed GL changes

All additive. Sizes are GL's unconfirmed estimates for one person with tests, no dates.

| # | Gap | Proposed change | Size |
|---|---|---|---|
| G1 | VAT: no exempt-only path | Section 1.1: `vat_exempt_only` table (verified flag), route uses an empty schedule when every line is EXEMPT and the jurisdiction is flagged | Small |
| G2 | One revenue account per sale | `SaleLine` gains an optional credit account (REVENUE or LIABILITY, must belong to the Company); optional per-line dimensions (campus, level, fee item). Absent means today's behaviour. The AR debit and VAT lines are unchanged | Medium |
| G3 | No school accounts | `SCHOOL_FEES` pack plus an idempotent apply route (add missing by code) | Medium |
| G4 | No deferred income release | Thin `record-income-recognition` (Dr deferred, Cr revenue, one period per call). SOP owns the schedule because it knows the term dates; GL stays generic. Only if D1 chooses deferral | Small |
| G5 | Overpayment | `record-collection` gains an optional advance account and amount; one entry, Dr settlement, Cr AR (applied), Cr advances (excess) | Small to medium |
| G6 | No mapping mechanism (accounts are found by hard-coded codes) | `company_account_roles` (Company, role, account), versioned, seeded by applying the pack, readable through a `fee-posting-context` (role to account id, as `sales-posting-context` does for one role set today), editable by an Owner-Admin or finance role, audited. RECOMMENDED over SOP storing account ids on each billing item: the Company owns its accounts, accounts can be recoded, FIN-INT-015 asks for versioned maintenance, and it is the same single-source principle as the jurisdiction and VAT tables. The cheaper alternative is SOP storing account ids per item with GL only supplying the pack; it works but duplicates the mapping per consumer | Medium to large |
| G7 | Refund | Thin `record-customer-refund` (Dr advances or AR, Cr settlement), approver reference in the description | Small to medium |
| G8 | No reversal route | Expose `ReverseJournalEntryUseCase` as `POST /journal-entries/{id}/reverse` (closed-period guard already there), service-account callable, idempotent | Small |
| G9 | Credit note on a taxable line does not reverse VAT | Extend `record-sales-return` to reverse VAT by category. Not needed for exempt fees | Medium, later |
| G10 | Audit trail for VAT, exempt-only and role mapping | The append-only item already on the backlog, widened to these tables | Medium |
| G11 | Exempt versus out-of-scope | Pass-through collections are out of scope of VAT, not exempt. v1 records them as EXEMPT (no VAT line). A distinct category matters only when per-country VAT returns are built, and adding an enum value is a lockstep change for strict consumers | Deferred |

**Known limits, stated plainly:** exempt lines post no VAT line, so exempt turnover is not visible to a VAT return (see G11); GL has no consolidation; GL has no fund accounting; `record-collection` does not check the collection against the invoice balance (SOP's billing account is the control, GL records the effect); the generic journal route is available to SOP but is a blunt tool, so the thin interfaces above replace it where volume or risk justifies.

---

## 6. Idempotency, volume, references

- **Idempotency (FACT).** `record-sale`, `record-collection`, `record-sales-return` and the generic journal route honour `Idempotency-Key`, scoped per tenant and operation with a request hash, and keys are kept forever. A billing run is one call per invoice, keyed by SOP's invoice id, so a retried run cannot double-post. A replay of a key recorded before a response gained new fields returns the older stored body (SOP already treats new fields as nullable).
- **Volume.** About 1,000 calls per term for a 1,000-student school (NFR-GLFEE-02). Calls are independent transactions. Measure before adding a batch route.
- **Reference.** A journal entry has only a description and a source, no external reference column. v1: SOP puts its invoice or receipt number at the start of the description and stores the returned `journalEntryId`. A dedicated indexed reference column is a small migration, added only if reconciliation needs lookup by reference.
- **Currency (FACT).** A Company accepts any ISO currency. The "SLE only across the Mano River operation" and "hold GHS, GMD, LRD, GNF, XOF" decisions are platform policy for onboarding, not enforced in GL's posting code. NGN is a policy question for Femi (scope doc section 4.2), not a GL change.

---

## 7. What GL needs from the other halves

- **SOP:** the request shapes it will send (invoice with per-line item, account role, VAT category, dimensions; payment with channel and optional advance); the invoice and receipt number format for the reference; confirmation that it takes the tolerant-DTO-first release order again.
- **+ER Education:** the school-type taxonomy and the fee-item list that the role mapping must cover; which items are pass-through.
- **EA:** the school-to-Company mapping and where "apply the SCHOOL_FEES pack" is triggered (GL proposes: the onboarding step that creates the school's Company, so a school never reaches billing without its accounts).
- **WEB:** the screen for chart-of-accounts mapping maintenance (G6) and the Bursar's view; GL supplies the routes.
- **CM:** release order across GL, SOP, ER and EA; migrations (vat_exempt_only, pack, role table), numbered after V30; the integration tests against real Postgres as before.

---

## 8. Tasks (T), dependency ordered

| Order | Task | Depends on | Notes |
|---|---|---|---|
| T0 | Decisions D1 to D6 (section 9) | Femi, finance, +ER | Gates T3 mapping content, T6, and which of G4, G7 are needed |
| T1 | G1 exempt-only VAT path | D4 (country list) | Independent of the rest. Unblocks pilot for exempt fees. |
| T2 | G10 audit trail widened to VAT, exempt-only, roles | none | Must land before any country or the exempt-only flag is switched on in production |
| T3 | G2 per-line credit account and dimensions | none | Foundation for everything below |
| T4 | G3 `SCHOOL_FEES` pack and apply route | T3, D2 | Pack content is the signed-off mapping |
| T5 | G6 role mapping and `fee-posting-context` | T4, WEB screen | The alternative (SOP stores ids) removes this task |
| T6 | G5 overpayment split; G7 refund; G8 reversal route | T3 | G8 is independent and small: do it early, since SOP needs void and cancel for any billing |
| T7 | G4 income recognition | D1 = deferral, T3 | Skip if revenue is recognised at invoice |
| T8 | G9 VAT on credit notes; G11 category | taxable fees enabled | Later |
| T9 | Contract tests and a 1,000-invoice run | T3 to T6, SOP | Includes idempotent retry |
| T10 | Offline receipt-number ranges (FIN-INT-013) | local-first sync (scope section 4.7) | Out of this order; not before sync exists |

Suggested release shape: T1 and T2, then T3 and G8, then T4 and T5, then T6; each additive, SOP tolerant-first.

---

## 9. Decisions needed (not decided here)

| # | Decision | Owner | GL's recommendation |
|---|---|---|---|
| D1 | Revenue recognition: at invoice, or deferred and released over the term | Femi, finance | Deferral is the IFRS 15 treatment for fees billed before the term; recognising at invoice is simpler and common in small schools. GL supports either; deferral adds G4 and a monthly release run in SOP. Decide per school type and write it into the mapping. |
| D2 | Mapping per school type, and scholarships as expense versus contra-revenue | Femi, finance | Section 4. GL has no contra-revenue account type, so v1 posts them as expense (5500, 5510); a netted presentation is a reporting change |
| D3 | Designated or restricted levies: revenue now with a manual year-end transfer, or real fund accounting | Femi | Revenue now; fund accounting is a separate, larger piece |
| D4 | Which countries use the exempt-only path first, and confirmation that education is exempt (NG candidate; SL unknown) | Femi, against primary sources | Nigeria first, after confirmation |
| D5 | Student-level detail in the ledger | Femi, +ER | No: the payer is the ledger dimension, the student stays in SOP |
| D6 | NGN and any other currency not yet policy | Femi | Platform policy, not GL code |
| D7 | Scope doc questions already listed: first pilot school and country; whether the live switch waits for this epic | Femi | Not GL's call |

---

## 10. Risks

- **Misclassifying a fee as exempt** is the one real tax risk of G1. It is a configuration fact, gated by `verified`, audited (T2), and confined to all-exempt invoices.
- **One taxable line refuses a whole invoice.** That is correct (no partial posting), but SOP and ER must keep taxable goods off fee invoices until a schedule is verified.
- **Strict decoding.** Every new response field must be declared by SOP and WEB before GL ships it, the same order that worked for `cashAccountId`, `grossAmount` and `vatAmount`.
- **Mapping drift.** If account ids live on billing items in SOP (the alternative to G6), a recoded or replaced account silently breaks postings. The role table avoids that.
- **No consolidation.** A multi-campus group cannot be read as one set of accounts in GL.

---

## 11. Evidence (read 2026-10-07)

- `application/RecordSaleUseCase.kt`: single `revenueAccountId` on `Request`; lines are `(netAmount, vatCategory)`; Dr AR gross, Cr revenue net, Cr VAT per category; exempt posts no VAT line; `Success` now carries `grossTotal`/`vatTotal`.
- `application/RecordCollectionUseCase.kt`: Dr any settlement account, Cr AR, no type or balance check, no advance split.
- `application/RecordSalesReturnUseCase.kt`: Dr a caller-named account, Cr AR, no VAT reversal.
- `application/ReverseJournalEntryUseCase.kt`: exists; no route references it (grep).
- `domain/tax/vat_rate_schedule.kt`, `V30__vat_rates.sql`: rates are data; `verified` gates use; EXEMPT never stored and always supported; a schedule built from no rows is null.
- `domain/ledger/chart_of_accounts_template.kt`: Cash 1000 only; one revenue account per template; no bank, clearing, deferred, pass-through, advances, scholarship or bad-debt accounts; account codes in use listed in section 4.1.
- `application/ComputeSalesPostingContextUseCase.kt`: accounts resolved by hard-coded code (AR 1100, VAT 2150, cash 1000, lowest REVENUE code): there is no mapping mechanism.
- `domain/common/dimension_type.kt`: `COST_CENTER, DEPARTMENT, PROJECT, LOCATION, PRODUCT_LINE, CUSTOMER, VENDOR, ITEM, EMPLOYEE, CASH_FLOW_ACTIVITY, VAT_CATEGORY`.
- `domain/ledger/prepayment.kt`: the "one call = one period's release" shape G4 would mirror (domain only; no use case or route).
- `infrastructure/web/JournalEntryRoutes.kt`: generic `POST /journal-entries` and `POST /companies/{id}/accounts`, service-account callable through the existing write authorisation.
- `ER/Principal/docs/FiSH-ER-Education-Runtime-Technical-Req-Spec-and-Use-Cases-v0.1.md`: sections 2.7 (illustrative mapping), 4.10 (ER-FEE), 4.16 (FIN-INT-001 to 020), UC-10, UC-13.
- `docs/NG/NG_Tax_And_Currency_Settings.md` section 3 (education services exempt, NTA 2025); `docs/SL/SL_Tax_And_Currency_Settings.md` section 3 (single 15% GST, no exemption list found).
- `docs/GL_POP_IM_SOP_Backlog.md`: the pass-through row (its "existing CoA-mapping mechanism" question is answered here: there is none) and the audit-trail row for VAT changes.
