# SOP as the generic Accounts Receivable and income core: for any runtime (SPUTO)

**Status:** 2026-10-18, planning only, docs only, nothing in this note is built. Written by the SOP session for CM's programme "Generic core and runtimes" (Femi: "Today it is Education Runtime, tomorrow it can be Hospital Runtime, or AutoMechanic Runtime"). It builds on EA's platform-contract note of 2026-10-12 (the CONTRACT layer: versions, fixtures, registry, events) and does not repeat it. **Every claim is marked VERIFIED (read in code or a merged design note, with the file) or ASSUMED.** Sizes are the SOP session's estimates and are unproven. Paper runtimes: Education (live), Hospital and AutoMechanic (neither exists; their needs are my reasoning, not requirements anyone gave).

**The principle being tested:** SOP, IM and POP are the heartbeat of any organisation. A runtime keeps its own domain (admissions, patients, vehicles) and its own words, and SOP sells and collects for it through generic routes; a runtime never grows a second invoicing model.

## 1. Scope (S)

**SOP is the receivables and income core.** In scope for this note: sell (goods and services, credit and cash), bill (invoice and its document), collect (receipts, part payments, overpayments, third-party payers), credit (returns, credit notes, waivers and discounts), age (open items by payer and date), account (customer balances, statements, reminders), reconcile to the ledger's receivables control account.

**Out of scope, and why:** the runtime's own records (a student, a patient, a visit or encounter, a vehicle, a job card, a clinical note): they stay in the runtime; SOP only carries an opaque reference to them. Price lists and catalogues (that is IM's items core; the SOP line only points at an item). Claims adjudication (an insurer deciding what it will pay is the runtime's and the insurer's; the receivable that results is SOP's). Anything about payables or stock (POP, IM).

**Where SOP stops and GL starts:** GL holds the money fact and the control accounts; it aggregates. SOP owns the receivables sub-ledger (open items, ageing, statements) and reconciles to GL's account 1100. This was decided (Femi, 2026-10-18: "Accounts Receivable is a primary function of SOP").

## 2. Requirements (P)

IDs are `G-` generic (every runtime needs it) or `R-` runtime-specific (belongs in a runtime or in data). "Today" says what SOP does now.

### 2.1 Parties and accounts
- **G1 Customer is a generic account holder.** VERIFIED (`domain/salesorder/customer.kt`): a Customer has a name, credit terms, an optional facility and aval arrangement, an optional contact email, and belongs to one Company. Nothing in it names a school, a patient or a vehicle. The "guardian" is only ER's meaning of a Customer.
- **G2 Payer and beneficiary are different things.** Whoever is billed (the account holder) is not always whom the service was for: a guardian for several children, an insurer for many patients, a fleet owner for many vehicles. Today SOP has ONE free-text `customerReference` per sale (at most 100 characters, print-only, `domain/salesorder/line_quantity.kt`), so a per-student, per-patient or per-vehicle view cannot be read from SOP; ER keeps its own mapping for this (ER design note section 17/18). ASSUMED gap for Hospital and AutoMechanic (same shape). **Requirement:** a structured, optional **beneficiary reference on each sale line** (a kind code, an opaque id, a display label), owned and defined by the runtime, never interpreted by SOP, indexed so statements and ageing can be filtered by it. Per line, not per sale: a guardian's invoice carries lines for several children; an insurer's claim carries lines for several patients; a job has one vehicle (one value on every line).
- **G3 Third-party payers.** DECIDED (Decisions Log 2026-10-13) as a generic capability and designed in `SOP_Third_Party_Payments_And_Discounts_Given.md` (payer on the collection, several payers on one invoice, the customer never changes): the payer is data on the payment (name, relationship, reference), no sponsor master record. Not built. The relationship list there (SPONSOR, EMPLOYER, INSURER, CHARITY, OTHER) is already runtime-neutral.
- **G4 Payer split at billing (new, not covered anywhere).** A single service can be owed partly by one party and partly by another from the moment it is billed: a patient's visit where the insurer owes 80% and the patient 20% (a co-pay); a school fee where a sponsor pays one part. Today one sale has one Customer and one receivable. ASSUMED requirement for Hospital (strong) and Education (weaker, the sponsor case is handled after the fact by G3). Options are in section 7; this is the biggest open design point of the whole note.

### 2.2 Selling
- **G5 Ordinary credit and cash sale of services and goods through one route.** VERIFIED (`POST /api/sales`, `RecordOrdinarySaleUseCase`): lines with description, decimal quantity, price, an optional IM item; a credit or a cash method; idempotent by key; the VAT category comes from the IM item (merged as master 7f01125, live per CM as :58). Service items (no stock): built on branch `feature/er-credit-sale-s1`, reviewed, NOT released; needs IM's service-item slice deployed.
- **G6 One revenue account for the whole sale is the wrong shape.** VERIFIED: GL's posting context picks the lowest-coded REVENUE account in the Company's chart for every sale (`ComputeSalesPostingContextUseCase`), and SOP passes it through. A school needs tuition vs boarding vs transport; a hospital consultations vs procedures vs pharmacy; a garage labour vs parts. Femi: the account is determined by the transaction type through the Company's chart, Suspense (3910) when none. Design approved (`GL_Per_Line_Account_Routing_Audit_And_Design.md`, `SOP_Sale_Revenue_Account_Per_Line_Note_2026-10-18.md`), not built: the account is a per-line field, copied from the IM item (goods) or named by the caller (service/fee lines), omitted = Suspense.
- **G7 Service period and service date.** VERIFIED: one optional service period (from, to) and one reference per sale, print-only, never an input to recognition (`SOP_Decimal_Quantity_And_Customer_Reference_SPUTO.md`). A hospital bill has a service date per line (a stay spans days; procedures happen on different days); a school invoice may cover a term per line. ASSUMED requirement: an optional service date (or period) per line. Revenue timing stays at the invoice date for now (decided for the first school build).
- **G8 The trade-finance machinery is an optional module, not part of the generic path.** VERIFIED: the ordinary-sale path builds a full order and silently performs the trade-finance steps (`confirmAval(SALES_ADMIN)`, `fulfillLine` for every line, delivery terms "N/A - ordinary sale", `RecordOrdinarySaleUseCase`), and the Customer carries `avalArrangement`/`facilityId`. Hospital and AutoMechanic must never meet "aval" or "facility". Nothing the runtime sees is wrong today (the words stay inside SOP), but it is a leak of one vertical into the core. Requirement: the ordinary path must not depend on those steps; trade finance stays available behind its own routes for Tenants that use it (Femi: kept, generic, for the Tenant's own lender).
- **G9 Quotes / estimates / job cards before an invoice.** NOT built (no quote model; waiting on Femi). AutoMechanic needs an estimate that becomes a job and then an invoice; Hospital a treatment plan or pre-authorisation. The generic need is a **sales document in a state before invoicing**, converted to a sale without retyping. ASSUMED; a runtime may hold its job card and call the ordinary sale at invoice time until SOP has a quote, which is the cheaper first step.

### 2.3 Collecting
- **G10 Receipts register, payment method, numbered receipts.** Receipts register and credit application: VERIFIED built on branches (`feature/ar-receipts-credit-application`, reviewed three times, not released). Payment method (cash, bank transfer, mobile money mapped to the Company's books) and per-Company numbered receipts (reserved before the ledger posting, visible VOID): decided and designed, not built (`SOP_Payment_Method_And_Receipt_Number_Note_2026-10-18.md`).
- **G11 Overpayment and advances.** DECIDED (Femi): an overpayment is allowed and kept as its own traceable record (held, later refunded or reclassified); GL's "Overpayments on Invoice" account is the home (`GL_Overpayments_On_Invoice_Note.md`). VERIFIED built as data, the posting waits for GL. Hospital deposits and garage prepayments are the same mechanism; applying a held balance to a later invoice is GL's "apply" move, SOP's approval. ASSUMED that deposits need nothing else.
- **G12 Bill-for-collection (trade finance) collections reach the sub-ledger.** VERIFIED gap, decided to fix (about 1 day): a collected bill posts to GL but records no receipt on the sale.

### 2.4 Credits
- **G13 Credit notes exist only for goods returns.** VERIFIED: a credit note is issued from an inspected return request (quantities, reason codes DAMAGED, DEFECTIVE, WRONG_ITEM, CUSTOMER_CANCELLATION, LATE_DELIVERY, OTHER, dispositions RESALEABLE, REPAIRABLE, SCRAP, DISPUTE: `domain/returns`). A school waiver, a hospital billing correction, an insurer's contractual write-down, a garage goodwill credit are NOT goods returns. A free-standing credit/adjustment against an invoice has a draft design (`Sales_Returns_Credit_Notes_SOP_Half.md`, `SOP_Third_Party_Payments_And_Discounts_Given.md` FR-DG02: a discount-kind credit note) awaiting Femi. **Requirement:** one adjustment mechanism with a kind (return, discount/waiver, write-off, contractual adjustment, goodwill) and a reason, each with its own posting account from the chart.
- **G14 Complaints.** VERIFIED: the complaint module belongs to the returns flow (goods dispositions). Generic enough to leave; a hospital would call it a grievance. Not on the critical path.

### 2.5 Ageing, statements, reminders
- **G15 Ageing and the dashboard figures.** VERIFIED built on branches, not released: SOP's own ageing summary (EA's shape), open amount per sale, true as-of and invoice date still to do (`SOP_Accounts_Receivable_Completeness_Assessment_2026-10-18.md`). Ageing must be filterable by payer and by beneficiary (G2) and **by payer class**: insurer receivables are chased on different cycles (often 60 to 120 days) from patient or fee receivables. ASSUMED: ageing buckets stay a fixed set now, configurable later.
- **G16 Statements and reminders.** NOT built. A statement per payer and per beneficiary; reminders manual first (decided direction).

### 2.6 Documents and numbering
- **G17 Document words and numbers.** VERIFIED: the invoice document is titled "Invoice" (or "Receipt" when fully paid), prints the Company name, the customer, lines, net/VAT/gross and the optional reference and service period (`InvoiceDocument`); the invoice number is `INV-` plus the first 8 hex characters of the order id, deliberately not a sequence. Requirements: (a) the document title and column words are data per Company or runtime ("Invoice", "Fee statement", "Patient bill", "Job invoice"), default unchanged; (b) a **gapless per-Company invoice number series**, like the receipt series already decided. ASSUMED, not verified for any jurisdiction: many tax regimes require sequential invoice numbers; SOP's non-sequential number would then be a legal gap for every runtime, not a vocabulary issue.
- **G18 Tax.** VERIFIED (rule) and ASSUMED (coverage): a line's VAT category comes from its IM item, rates from GL per jurisdiction and period. School fees and many hospital services are exempt in many countries; a garage sells at the standard rate. This works through the item category without runtime code; per-country correctness is GL's.

### 2.7 Identity, access and wiring
- **G19 A runtime's credential is data.** VERIFIED Education-specific code in SOP: a login provider named for the Education Runtime (`SOP_JWT_SERVICE_AUTH_NAME_EDUCATIONRUNTIME`, `buildJwksServiceVerifierForEducationRuntime`), one env var for its audience (`SOP_JWT_SERVICE_AUDIENCE_SCHOOLADMISSIONS`, an old name), a Company allow-list env var (`SOP_ER_COMPANY_IDS`), per-route opt-in `serviceMayCall` (customers; the sale and collection routes on branches), and a planned school rule that asks EA whether the Company is a SCHOOL (`ER_Credential_School_Company_Rule_Design_Note.md`). A second runtime would need a second provider and a second list. **Requirement:** one service-credential mechanism where each runtime is a registered row (audience, allowed routes, allowed Companies from EA), not a code branch (EA's "registry", Layer B). The allow-list and the SCHOOL check become "this Company is registered for this runtime".
- **G20 `/me` and EA types.** VERIFIED: SOP's strict mirror of EA's `/me` carries `schoolId` (`infrastructure/ea/ea_dtos.kt`), a runtime-specific field every consumer had to add. A neutral shape (a runtime link, not a school field) is EA's change; SOP follows consumer-first.
- **G21 Idempotency, isolation, errors.** VERIFIED and already generic: Idempotency-Key on customer create, sale and collection (a derived key for credit notes); per-Company isolation and per-Tenant checks (T15 M1a); error body `{error, detail?, glError?}`; money as strings; strict decoding. These need no change for a new runtime.
- **G22 Events.** VERIFIED: SOP publishes no events and has no outbox; runtimes poll. A runtime that wants "payment received" must read SOP. ASSUMED fine until the event layer (EA's Layer C) exists; SOP would emit `invoice-issued`, `payment-recorded`, `credit-issued` in the shared envelope then.

### 2.8 Vocabulary each runtime would use for SOP's concepts
| SOP concept | Education | Hospital (paper) | AutoMechanic (paper) |
|---|---|---|---|
| Customer (account holder) | Guardian, sponsor | Patient (self-pay), insurer or scheme | Vehicle owner, fleet account, manufacturer (warranty) |
| Beneficiary reference | Student (+ term) | Patient visit / encounter | Vehicle + job card |
| Sale line | Fee item (tuition, boarding) | Consultation, procedure, drug, bed-day | Labour, part, shop supply |
| Invoice | Fee invoice / statement | Bill / claim | Job invoice |
| Receipt | Fee receipt | Payment receipt | Receipt |
| Adjustment | Waiver, scholarship, sibling discount | Contractual adjustment, write-off, correction | Goodwill credit, warranty credit |
| Third-party payer | Sponsor, employer | Insurer, scheme, employer | Warranty provider, insurer |
| Service period | Term | Admission period | Job dates |
These words live in the runtime and in WEB's vocabulary (WEB's part of this programme), not in SOP's routes; SOP's route and field names stay generic (sale, customer, collection, receipt, credit).

## 3. Evidence summary: where SOP assumes Education or a goods-and-trade-finance world
VERIFIED, by file:
- Education wiring (needs data, not code): `infrastructure/web/Auth.kt` (provider, verifier, env var, `serviceMayCall`), `Application.kt` (`SOP_ER_COMPANY_IDS`), `infrastructure/ea/ea_dtos.kt` (`schoolId`), `CustomerRoutes.kt` (comments only). The domain and application layers contain no education word (searched: education, school, guardian, tuition, student, patient, hospital, vehicle).
- Goods and trade-finance assumptions in the core: `RecordOrdinarySaleUseCase` (aval and fulfilment ceremony), `Customer.avalArrangement/facilityId`, `domain/returns` (goods-only), delivery terms default, the complaints flow.
- Single-valued where a runtime needs more: one reference and one period per sale, one customer per sale, one revenue account per sale, a non-sequential invoice number, invoice title fixed.
ASSUMED (not read or not decidable from code): the hospital and garage needs above; which jurisdictions require sequential invoice numbers; whether insurer ageing needs other buckets; whether a quote model is needed before a second runtime.

## 4. Use cases (U), in plain words
**Education (live; what works today and what does not).**
1. A school bills a term: three fee lines for one guardian, each a service item, the invoice posts once however many times the screen retries. *Built on a branch, not released; per-line revenue accounts and per-child lines (G2, G6) not built.*
2. A sponsor pays half, the guardian pays half. *Designed (G3), not built.*
3. A scholarship is granted after billing. *Designed as a discount credit note (G13), awaiting Femi.*
4. The bursar prints a receipt for each payment and a statement per guardian, and per child. *Receipts designed; statement per child needs G2.*
5. The term's overdue fees by class of payer. *Ageing built on a branch; filter by beneficiary needs G2.*

**Hospital (paper).**
1. Self-pay visit: consultation and two procedures (services) plus a drug (stock) on one bill, paid in cash at the desk, a numbered receipt printed. *Mixed service and stock lines work in one sale (tested on the fee-invoice branch, not released); numbered receipts designed.*
2. Insured visit: the bill is owed 80% by the insurer and 20% by the patient. *Not possible today (G4).* The insurer is billed per month for many patients' visits: one invoice, one line per patient visit (G2 per line).
3. The insurer pays 60 days later, 10% less than billed; the shortfall is a contractual write-down, not bad debt. *Needs the adjustment kinds (G13) and payer-class ageing (G15).*
4. A patient pays a deposit on admission and the final bill is smaller than the deposit; the balance is refunded. *Overpayment mechanism (G11): data built, posting and refund act waiting.*
5. A billing error: the wrong procedure was charged. *A credit/adjustment (G13), not a goods return.*

**AutoMechanic (paper).**
1. Estimate, then job, then invoice for labour (service) and parts (stock). *No quote (G9); the runtime keeps its job card and calls the ordinary sale at invoice time.*
2. A warranty repair: parts are owed by the manufacturer, labour by the customer. *The same payer split as G4.*
3. A fleet customer on 30-day terms gets one monthly statement across many vehicles. *Terms and statement (built / designed), per-vehicle filter needs G2.*
4. A part is returned unused. *This one IS a goods return and works end to end (stock back, credit note).*

## 5. Tasks (T), dependency-ordered, with owner and estimate
Already decided and queued (not new, shown for the order): ① release the receipts/credit/ageing branches (CM); ② payment terms and due date (SOP+POP, 1.5 d SOP); ③ fee-invoice route for the school credential, release and IM service items (SOP/IM/ER/CM); ④ per-line revenue account (GL first, then SOP 2 d); ⑤ invoice date and true as-of (0.5 d), Bill-for-Collection receipts (1 d), query batching (1 d); ⑥ payment method and numbered receipts (SOP 4.5 d); ⑦ third-party payer on a collection (T1/T2 of its note, about 3 d).

New, from this exercise:
| # | Task | Owner | Size | Depends on |
|---|---|---|---|---|
| N1 | **Beneficiary reference per sale line** (kind, id, label; stored, returned, indexed, filter on statements and ageing) | SOP; runtimes send it | 1.5 d | ⑤; Femi D1 |
| N2 | **Payer split at billing** (design first, then build) | SOP+GL design, SOP build | design 1 d, build about 5 d | Femi D2 |
| N3 | **One adjustment mechanism with kinds** (return, discount/waiver, write-off, contractual adjustment, goodwill) incl. posting account per kind | SOP+GL | design 0.5 d (extends the draft), build about 3 d | Femi on the draft; ④ |
| N4 | **Gapless per-Company invoice number series** (same mechanism as receipts) | SOP | 1 d | ⑥ design; Femi D3 |
| N5 | **Document words as data** (title and column words per Company or runtime) and **service date per line** | SOP (+WEB) | 1 d | Femi D4 |
| N6 | **Take the trade-finance ceremony out of the ordinary path** (no aval/fulfil steps; keep them behind the trade-finance routes) | SOP | 1 d, careful (every sale touches it) | tests first; ① |
| N7 | **Runtime credentials as registered data** (replace the Education-named provider, env var and allow-list by EA's runtime registry) | EA first, SOP | SOP 1.5 d | EA registry (Layer B), the school rule's EA route |
| N8 | **Customer statement** per payer and per beneficiary, then **manual reminders** | SOP | 1.5 d + 2 d | ① ⑥ N1 |
| N9 | **Payer-class ageing** (insurer vs patient buckets) | SOP | 1 d | N1, N2 |
| N10 | **Quote / estimate document before an invoice** | SOP | design first, build about 4 d | Femi D5; only when a runtime needs it |
| N11 | **Events** (invoice issued, payment recorded, credit issued) in the shared envelope | SOP | 2 d | EA Layer C |

## 6. Order (O)
**What can ship before a second runtime exists, because it is generic and already needed by Education:** ① to ⑦ above, plus N1 (the school needs per-child lines too), N3, N4, N5, N6. All are neutral changes that cost little now and are expensive to retrofit once data exists (the invoice number series above all, N4).
**What waits for a second runtime to be decided:** N2 (payer split) is needed first by Hospital; build it when Hospital is real, but DESIGN it now (it shapes the sale, receivable and statement model, so a wrong early choice is costly). N9, N10, N11, and N7 beyond the Education registration.
**Recommended sequence:** release ①; then the cheap neutral changes N4, N1, N5 in the same migration window as ② and ⑤ (they touch the same tables); N6 with its own tests; N3 when Femi approves the draft; design N2 in parallel with GL; N7 when EA's registry exists.

## 7. Open decisions for Femi, with my recommendation
- **D1 Beneficiary reference: per line or per sale?** Recommend **per line**, optional, structured (kind code, opaque id, display label), runtime-defined, never interpreted by SOP. A guardian's invoice and an insurer's claim both carry several beneficiaries; per sale cannot express that.
- **D2 Payer split at billing.** Options: (a) two invoices from one visit, one to each payer, created together by the runtime (no SOP change; the link between them is the runtime's; simplest; statements per payer work; reconciling "one visit" is the runtime's job); (b) one sale with payer shares per line or per percentage, producing two receivables inside SOP (richer, and a real change to the sale, customer balance and ledger tagging); (c) bill the patient only and reclaim from the insurer later as a separate claim sale. **Recommend (a) for the first Hospital release**, designed so (b) can follow: it keeps SOP's one-sale-one-customer rule and needs only N1 to tie the two invoices to the same visit.
- **D3 Sequential invoice numbers.** Recommend **yes**, a gapless per-Company series like the receipts (reserve before posting, visible VOID), with the current `INV-xxxxxxxx` kept as a reference on old invoices. If any target jurisdiction does not require it, the cost is still low and the benefit (a number an accountant and an auditor can follow) is real. Needs a check of the real requirement per country (not verified here).
- **D4 Document words as data?** Recommend yes: title and heading words per Company (default unchanged), nothing structural. Cheap, and it is what makes a hospital's "Patient bill" not look like a school's invoice.
- **D5 Quotes: now or when a runtime needs them?** Recommend **when a runtime needs them**: the runtime keeps its job card or plan and calls the ordinary sale at invoice time. Revisit at the first AutoMechanic or Hospital build.
- **D6 One adjustment mechanism with kinds, or separate features?** Recommend **one**, kinds as data with a posting account each (waiver, scholarship, write-off, contractual adjustment, goodwill, return), so a new runtime adds a kind, not a feature.
- **D7 Is a service line without an IM item allowed for good?** Today a line with no item and an explicit VAT category is allowed (the seller picks the category). Femi's rule says the category lives in IM. Recommend: keep it for a person's one-off line, refuse it for any runtime credential (already how the school route is built), so every runtime sells through its catalogue.

## 8. What I could not verify
- Any hospital or garage requirement: they are my reading of the brief, not facts from a user.
- Which tax authorities require sequential invoice numbers, and whether insurer ageing needs different buckets.
- Whether EA's runtime registry will carry allowed routes per runtime (I assumed it can).
- The exact shape of the beneficiary field a runtime would send: kind codes are the runtime's; I have not asked ER what it would put there.
- Performance of ageing and statements on large Companies (the query batching task is open).
