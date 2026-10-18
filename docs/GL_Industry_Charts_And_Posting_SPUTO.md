# GL: industry charts of accounts and posting rules per runtime (SPUTO)

**Status:** 2026-10-18, planning only. Nothing in this note is built. Written by the GL session for CM's programme "generic core first, runtimes specialise by data" (Femi: "Today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime etc."). Builds on `docs/reports/Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` (the contract layer, not repeated here) and on GL's own account-per-transaction-type design (`docs/GL_Per_Line_Account_Routing_Audit_And_Design.md`). SPUTO = Scope, Plan (requirements), Use cases, Tasks, Order.

**Labels:** **VERIFIED** = read from GL code or a source doc on 2026-10-18. **ASSUMED** = GL's reasoning about a runtime that does not exist yet, to be confirmed by an accountant (Femi is the tax professional). **OPEN** = a decision for Femi.

---

## S. Scope

**In.** What the ledger needs so that any runtime can run on the generic services: (1) how a Company's chart of accounts is chosen and extended for an industry; (2) the account roles each of three runtimes needs (Education, live; Hospital and AutoMechanic, paper only); (3) the posting rules each runtime's transactions use, through the generic services' thin GL interfaces; (4) tax by jurisdiction in each.

**Out.** The runtimes' own domains (admissions, patients, vehicles), their vocabulary and screens (WEB, the runtimes), SOP/IM/POP internals (their own SPUTOs), runtime registration (EA). Any build for a runtime nobody has decided to build. Accounting policy questions that need Femi's professional judgement are marked OPEN, not decided here.

**The principle that decides the design.** GL is generic. It knows no industry. A runtime never posts to GL; the generic services (SOP, IM, POP, HR, and Payroll) do, through thin interfaces, and a runtime specialises by **data**: which accounts exist in the Company's chart, and which account each item, fee, procedure or part posts to.

---

## P. Plan: requirements

### P1. Where GL stands today (VERIFIED)

1. **The chart is chosen by business structure, not industry.** `ChartOfAccountsTemplate.accountsFor(clientType, companyId)` (`domain/ledger/chart_of_accounts_template.kt`) has five templates: individual, sole trader, partnership, limited company, non-profit. The four business templates are the same except for the equity names and (non-profit) the revenue and expense names; each adds the same packs (payroll, reporting expenses, fixed assets and inventory, trade finance facility, VAT, Discounts Received). A business chart has **one** revenue account (`4000 Sales Revenue`) and **one** operating expense account (`5000 Operating Expenses`), plus cost of sales, interest, tax, depreciation, payroll. **There is no per-industry chart.**
2. **GL stores no industry.** `Company` (`domain/tenancy/company.kt`) has tenant, name, client type, jurisdiction, base currency; no industry field. Industry lives in EA (`IndustryType`, closed enum of two values per the contract SPUTO).
3. **Charts can already be extended idempotently.** `AddMissingStandardAccountsUseCase` adds the accounts a template has and the Company lacks, by code, never changes or replaces one that exists, and reports conflicts. It is the seed of an "account pack" mechanism; today it only knows the one template.
4. **Posting code is runtime-neutral.** A search of GL's main source for school, tuition, student, guardian, education, hospital, patient and vehicle finds **no posting logic**; the only Education references are `ManagedModule.EDUCATION_RUNTIME` (`domain/tenancy/managed_module.kt:50`, a visibility value) and the `schoolId` field GL mirrors from EA's `/me` (`infrastructure/ea/ea_dtos.kt:29`). The words "vehicle registration" appear only as an example for a fixed asset's identifier.
5. **But today's thin interfaces are not yet neutral in a different way:** a sale credits **one** revenue account for the whole invoice and a purchase debits one expense account, both picked by the posting contexts as the lowest-coded account of the type (`ComputeSalesPostingContextUseCase`, `ComputePurchasePostingContextUseCase`); settlement defaults to cash 1000; `ModuleOwnedAccounts` assumes the business codes (1100, 2000, 1300, 1200, 2150). A hospital with consultations, procedures and pharmacy sales, or a workshop with labour and parts, cannot be reported by stream until each line names its own account. **The per-line account work (built, awaiting release) is the prerequisite for every industry chart below.**
6. **Dimensions exist but the thin interfaces tag only a few.** `DimensionType` has COST_CENTER, DEPARTMENT, PROJECT, LOCATION, PRODUCT_LINE, CUSTOMER, VENDOR, ITEM, EMPLOYEE, CASH_FLOW_ACTIVITY, VAT_CATEGORY, VAT_DIRECTION. The thin posting routes set CUSTOMER or VENDOR, the VAT tags and the cash-flow activity; none sets DEPARTMENT, LOCATION or COST_CENTER.
7. **Tax is per jurisdiction, not per industry.** `VatRateSchedule` rows exist and are verified for Ireland (five bands) and the United Kingdom (three); Sierra Leone's 15% is loaded but unverified (refuses); Liberia, Guinea, Cote d'Ivoire and Nigeria have no rows (`docs/<country>/..._Tax_And_Currency_Settings.md`). EXEMPT has no rate and is outside VAT. The "exempt-only governed path" proposed for fee-only schools (the fee-billing GL posting rules note, section 1.1, kept in the private reports folder) is **not built** (no code for it was found).

### P2. Requirements (numbered)

| ID | Requirement | Generic or runtime-specific |
|---|---|---|
| GLRT-01 | GL knows no industry. A Company's chart is the union of a **base chart** (by client type, as today) and zero or more **account packs** chosen when the Company is provisioned. | Generic |
| GLRT-02 | An account pack is **data**: a versioned list of accounts (code, name, type, classification, expense classification, an optional **role** label) that is applied **idempotently by code** (add what is missing, never change or delete, report conflicts), as `AddMissingStandardAccountsUseCase` already does for the one template. A pack can be applied to a new Company at provisioning and to an existing Company later. | Generic mechanism; the contents are runtime-specific |
| GLRT-03 | Packs are owned by GL and selected by **pack id** supplied by whoever provisions the Company (EA, from the industry), so a new runtime adds a pack, not a branch of code in GL or EA. GL records which packs and versions were applied to a Company (audit). | Generic |
| GLRT-04 | Every generic service posts each line to an account **from the Company's own chart** (item, fee, procedure or part carries its account; IM owns the default, the line may override); a line with no account goes to Suspense 3910, never to a default account. | Generic (built, awaiting release) |
| GLRT-05 | A **role** (for example "patient service income", "contractual adjustment", "parts cost of sales") is a label on an account in a pack, so an item master or a screen can offer "the accounts that can play this role" without knowing codes. A Company may re-point a role to another of its accounts. GL serves the Company's accounts by role. | Generic mechanism; role names runtime-specific |
| GLRT-06 | Account codes in packs follow reserved ranges so packs never collide with the base chart or each other (OPEN: ranges, section Decisions). | Generic |
| GLRT-07 | Third-party payers (an insurer, a scheme, a sponsor, a manufacturer paying warranty work) are **SOP customers**; GL sees them only through the CUSTOMER tag on Accounts Receivable. GL adds no per-payer accounts. Whether a payer class gets its own **control** account for presentation is OPEN. | Generic |
| GLRT-08 | The thin interfaces accept optional **dimensions** per line (DEPARTMENT, LOCATION, COST_CENTER, PRODUCT_LINE, or an opaque reference such as an encounter or job number) that GL stores as audit tags and does not validate against a list, so a runtime can analyse by ward, bay or class without GL learning its catalogue. | Generic (not built; OPEN) |
| GLRT-09 | Tax follows the Company's **jurisdiction** and the item's **VAT category** (decided: category per item, per jurisdiction and period, IM-owned); GL computes the VAT. An industry changes which categories its items carry, never GL's code. A jurisdiction with no verified rates refuses a taxable line; an all-EXEMPT sale needs the governed exempt-only path (not built). | Generic; categories per runtime |
| GLRT-10 | Reports (trial balance, P&L, balance sheet, trading P&L) work unchanged for any chart; the **trading P&L's** cost-of-sales and interest tags must be set by the pack so the report is trustworthy on day one (`costOfSalesConfigured`, `interestConfigured`, `taxConfigured`). | Generic; tags set by pack |

### P3. Account roles per runtime (ASSUMED: for an accountant to confirm)

Names are roles, not codes. "Base" means already in every business chart.

**Generic base (all runtimes).** Cash and bank books; accounts receivable (base); inventory (base); fixed assets, accumulated depreciation, depreciation (base); accounts payable (base); VAT control (base); wages, salaries, leave (base); equity and suspense (base); Discounts Received (base); cost of sales (base); gain and loss on disposal (built, awaiting release); Overpayments on Invoice (designed, awaiting Femi); goods received not invoiced and purchase price variance (designed, seam A).

| Role | Education | Hospital | AutoMechanic |
|---|---|---|---|
| **Income streams** (one account each, picked by the item) | Tuition; boarding; examination and activity levies; uniform and book sales | Consultations; procedures; laboratory and imaging; ward and bed charges; pharmacy sales | Labour; parts sales; diagnostics; sublet work |
| **Pass-through liabilities** (money collected for someone else) | Parent-teacher association and external examination fees | Third-party fees collected (for example a visiting specialist's share) | Customer deposits on orders |
| **Deferred income** (billed before earned) | Fees billed before the term (release over the term, before Live) | Patient prepayments / deposits | Deposits on jobs not started |
| **Contra-income** (reduce income, not an expense) | Scholarships, waivers, discounts | Contractual adjustments (what an insurer will not pay), charity care, discounts | Goodwill discounts |
| **Third-party receivables** | Sponsors, bursary bodies | Insurers and schemes (claims submitted, claims paid) | Manufacturer / warranty claims |
| **Cost of sales** | Cost of uniforms and books sold | Drugs and consumables used (stock issue) | Parts used on jobs; sublet cost |
| **Provisions** | Bad-debt allowance (expected credit loss) | Bad-debt allowance; claims disallowed | Warranty and comebacks provision |
| **Equipment** (fixed asset categories) | Classroom, laboratory, ICT | Medical equipment | Lifts, diagnostic tools, tools |

Sizes: Education roughly 8 to 12 accounts beyond base, Hospital 12 to 18, AutoMechanic 8 to 12 (ASSUMED).

### P4. Posting rules per runtime event (through the generic thin interfaces)

All use the per-line account route (`record-sale`, `record-obligation`, `record-collection`, `record-credit-note`, `record-sales-return`, inventory receipt and issue, the payroll routes). Each line names an account; a missing account is Suspense.

**Education (live, VERIFIED design in the fee-billing docs):**
- Tuition invoice, credit sale: Dr Accounts Receivable (gross, tagged to the payer), Cr Tuition (per line), Cr VAT only where the item's category is taxable (education is often exempt: OPEN per country).
- Fee paid by cash, bank transfer or mobile money: Dr the school's mapped cash or bank book, Cr Accounts Receivable.
- Overpayment: the excess Cr Overpayments on Invoice (liability), not AR.
- Scholarship / waiver: Dr Scholarships (contra-income), Cr Accounts Receivable.
- Books and uniforms: Dr AR, Cr income, Cr VAT; stock issue Dr cost of sales, Cr inventory.

**Hospital (ASSUMED):**
- Consultation or procedure, insured patient: Dr AR (patient share) and Dr AR (insurer share), Cr the service income account per line, Cr VAT where taxable. Two SOP customers, one invoice split by payer.
- Drugs dispensed: Cr pharmacy income, and a stock issue Dr drugs cost of sales, Cr inventory at average cost.
- Claim paid by the insurer for less than billed: Dr bank, Dr contractual adjustment (contra-income), Cr AR (insurer). The adjustment is an explicit posting, not a silent write-off.
- Patient deposit: Dr cash, Cr patient deposits (liability); applied at discharge: Dr deposits, Cr AR.
- Supplies bought: POP; drugs received into stock: IM receipt.

**AutoMechanic (ASSUMED):**
- Job card closed: Dr AR, Cr Labour income and Cr Parts sales (per line), Cr VAT standard-rated; parts issued Dr parts cost of sales, Cr inventory.
- Warranty job: the customer is the manufacturer (an SOP customer); Dr AR (manufacturer), Cr labour and parts income; a warranty provision is a separate estimate (IAS 37, `Provision` exists in the domain).
- Parts bought: POP; returned to supplier: the return posting (design agreed with POP).
- Customer deposit on a special order: Dr cash, Cr customer deposits; applied on invoice.

### P5. Tax by jurisdiction in each runtime

- **Mechanism (VERIFIED):** the Company's jurisdiction selects the VAT schedule; the item's category (set per jurisdiction and period in IM) selects the rate; GL refuses a taxable line where no verified rate exists.
- **Education:** usually exempt or outside VAT, but the rule is per country and per period (Femi's decision, 2026-10-13), never a default. Uniforms and books are normally taxable. Nigeria lists education as exempt in the settings doc (a candidate, not confirmed); Sierra Leone has no exemption list found (genuinely unknown).
- **Hospital (ASSUMED):** medical services are exempt in many jurisdictions while drugs may be exempt, zero-rated or standard-rated; consumables and equipment standard-rated. Needs a per-country list from Femi before any hospital pack ships.
- **AutoMechanic (ASSUMED):** labour and parts standard-rated; warranty work billed to a manufacturer follows the same category.
- **Corporate income tax** is per jurisdiction (the existing `TaxRule`); a school or hospital may be a non-profit (the `NON_PROFIT` client type exists) or for-profit, so the tax result follows client type, not runtime (ASSUMED, to confirm).

---

## U. Use cases (plain words)

**Education.** (1) A school opens its books: it gets the base chart plus the Education pack, so Tuition, Boarding, Levies, Scholarships and Parent Advances exist from day one. (2) The finance officer bills a term's fees: each fee posts to its own income account; the guardian owes the total. (3) A parent pays half by mobile money: the school's mobile-money book is debited and the guardian's balance falls by half. (4) A parent pays too much: the extra is held as Overpayments on Invoice until applied or refunded. (5) The head grants a scholarship: it reduces income, not expenses, and the invoice shows it. (6) A school that existed before the pack gets the missing accounts added in one step, nothing changed or removed.

**Hospital.** (1) A clinic opens its books: base chart plus the Hospital pack. (2) A patient with insurance has a consultation and a lab test and is given drugs: the bill is split between patient and insurer, each line posts to consultations, laboratory or pharmacy income, and the drugs leave stock at cost. (3) The insurer pays 90 per cent of what was claimed: the 10 per cent difference is a contractual adjustment against income, visible in the books. (4) A patient pays a deposit before surgery and it is applied at discharge. (5) The clinic buys drugs and consumables from suppliers through POP and sells some over the counter.

**AutoMechanic.** (1) A workshop opens its books: base chart plus the AutoMechanic pack. (2) A customer's car is repaired: labour and parts are separate lines with separate income accounts; parts leave stock at cost; VAT is standard-rated. (3) A job under manufacturer warranty is billed to the manufacturer, not the car owner. (4) The workshop buys parts through POP and returns a wrong part for a credit. (5) A customer leaves a deposit on a special-order part; it is applied on the invoice.

---

## T. Tasks (dependency-ordered; sizes are GL-side estimates)

| # | Task | Owner | Size | Depends on |
|---|---|---|---|---|
| 1 | Release the built work this plan rests on: per-line accounts, `total`/`vat` on obligations, disposal gain/loss, `taxConfigured`, settlement accounts and receipt reference | GL, CM | queued | review |
| 2 | Overpayments on Invoice, gain/loss and PPV/GRNI standard accounts: confirm codes (Femi), seed in the base chart and standard-accounts route | GL, Femi | 1 d | 1 |
| 3 | **Account pack mechanism:** generalise `AddMissingStandardAccountsUseCase` to apply a named, versioned pack idempotently by code; record packs applied per Company; route to list packs and apply one | GL | 2 d | 1 |
| 4 | Account **roles**: a role label on pack accounts, `GET accounts?role=` and re-pointing a role per Company; picker support in `usableFor` | GL | 2 d | 3 |
| 5 | Provisioning accepts optional `packIds` (additive) so EA can apply the right packs when it creates a Company for an industry | GL, EA | 1 d GL | 3 |
| 6 | Education pack as data (tuition, boarding, levies, pass-through liabilities, deferred fee income, scholarships, parent advances) after Femi's accounting review; the fee-billing notes already specify most roles | GL, Femi | 1 d + review | 3, 4 |
| 7 | Optional per-line dimensions on the thin interfaces (opaque reference plus DEPARTMENT, LOCATION, COST_CENTER, PRODUCT_LINE) | GL | 2 d | 1 |
| 8 | Contra-income support: Discounts Given and a proper Sales Returns / Scholarships / Contractual adjustments role, with VAT reversal where taxable | GL | 3 d | 1, 4 |
| 9 | Deferred income and its release posting (schools bill before the term; hospitals and workshops take deposits) | GL, SOP | 3 d | 4 |
| 10 | Exempt-only governed VAT path and per-country verification of education and medical exemptions | GL, Femi | 1 d + research | decision |
| 11 | Hospital and AutoMechanic packs: **paper packs only**, reviewed by Femi, built only when a runtime is decided | GL, Femi | 0.5 d each to write | 3, 4 |
| 12 | Playbook, test plan and contract fixtures for each new route | GL | 1 d each task | each |

---

## O. Order, and what can ship before a second runtime exists

1. **Release the queue** (task 1). Everything else depends on accounts being chosen per line and on Suspense; this is already built.
2. **Tasks 2 to 5, then 6.** The pack mechanism, roles and the Education pack ship **without any second runtime** and change nothing for existing Companies (additive; packs applied only on request). They remove the single-revenue-account limit schools hit today.
3. **Tasks 7 to 10 as the runtimes need them**: dimensions, contra-income, deferred income and the exempt-only path serve Education first (fee billing) and become reusable for the other two at no extra cost.
4. **Task 11 last, and only on a decision:** the Hospital and AutoMechanic packs are written as documents for an accountant to review. Building them is a data insert once the mechanism exists, which is the test that the design is generic.

**What would prove genericity:** a third runtime's pack applied to a test Company, with a consultation or a job card posted through SOP, IM and POP, and no change to GL's source.

---

## Open decisions for Femi (plain words, with my recommendation)

- **D1. Who owns the packs?** GL (recommended): one place, versioned, applied by id; EA only names the pack. The alternative (each runtime holds its own chart) duplicates the ledger's knowledge.
- **D2. Should GL store an industry on the Company?** Recommend no; GL records the packs applied, which is enough for audit, and keeps the ledger generic.
- **D3. Account number ranges for packs.** Recommend reserved ranges (for example income streams 4100 to 4799, pass-through and deferred liabilities 2400 to 2499, contra-income 4800 to 4899, system accounts 4900s and 5500s as today). Your call on the scheme.
- **D4. Dimensions on the thin interfaces.** Recommend yes, optional and opaque, so a runtime analyses by ward, bay or class without GL learning its catalogue.
- **D5. Third-party payers.** Recommend one receivables control account with the payer as an SOP customer; add a separate control account per payer class only if a statutory presentation or the expected-credit-loss method needs it (a professional judgement).
- **D6. Accounting policies only you can set:** recognising school fees over the term (IFRS 15), insurer contractual adjustments and claim disallowances, warranty provisions, deposits as liabilities. I will draft nothing as settled; each is a pack design input.
- **D7. Tax:** the per-country, per-period exempt and taxable lists for education and medical services, before any pack that depends on them ships.

---

## What I verified and what I assumed

**Verified in code or source docs on 2026-10-18:** the five client-type templates and their shared packs; no industry on `Company`; the idempotent standard-accounts mechanism; no education/hospital/vehicle posting logic in GL main source (two Education references named above); the single-account posting contexts and the per-line work that replaces them; which dimensions the thin routes set; the VAT schedule states per country; no exempt-only path in code.

**Assumed (to be confirmed by an accountant before any pack is built):** every account role and the sizes in P3, all Hospital and AutoMechanic posting rules and use cases, the VAT treatment of medical services and drugs, the effect of a for-profit or non-profit client type on tax, and the reserved account ranges. I read nothing of the Education Runtime's, SOP's, IM's or POP's code for this note beyond the GL-side docs cited; their SPUTOs own those parts.
