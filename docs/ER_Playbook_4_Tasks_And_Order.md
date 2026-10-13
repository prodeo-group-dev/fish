# Education Runtime Playbook, part 4 of 4: Tasks (T) and Order (O), with the consolidated decision list

**Status:** DRAFT, 2026-10-13, planning only; **nothing is built until Femi approves the whole Playbook (parts 1 to 4 together).** Parts 1 to 3: `docs/ER_Playbook_1_Scope.md`, `docs/ER_Playbook_2_SRS.md`, `docs/ER_Playbook_3_Use_Cases.md`. Written by the Education Runtime (+ER) session. Evidence tags as before: **[code]**, **[decided]**, **[TBC]**. Sizes are **my estimates in builder-days of one session, unproven**: **S** up to 1 day, **M** 2 to 4, **L** 5 to 10, **XL** more than 10. They include tests, review and hand-off, and exclude waiting for other sessions or for Femi.

## 0. Rules every task follows

- **Deferred enforcement** (Femi, 2026-10-13): a new permission is designed now, built as a feature first, and **enforced later behind a flag that defaults OFF**, each flag in Part 2 section 1.1 and on CM's Live-switch checklist; a task's definition of done includes that listing.
- **Tests first**; real Postgres for anything touching money, idempotency, concurrency or a migration; declared test count equals executed count.
- **One branch per task** in the owner's own checkout, handed to CM as branch and tip; only CM pushes, merges and deploys. A task with a **⚑** has CM's recorded review before its build starts (RBAC change, new service-account scope, cross-Tenant read, children's-data export, authentication change).
- **Foundations first** (Femi, 2026-10-07): idempotency, concurrency and fail-closed configuration come before the features that depend on them.
- **No `ignoreUnknownKeys`** on any call that carries an access decision; every response ER provides or consumes has a fixture in `fish-contracts`.
- **A coordination row is claimed before work** (`ER/Principal/EducationRuntime/COORDINATION.md`), and **every dependency on another session is written on the row**. Migration numbers are reserved there.
- **No duplication** of the generic services (Femi); **ER never posts to GL**.
- Every task names the Part 2 requirements it delivers and the Part 3 use case that proves it.

## 1. The task list

Owner: **ER** the Education Runtime, **WEB**, **SOP**, **EA**, **HR**, **CM**. "Dep" are task ids that must be done first (or, with ~, may run in parallel).

### Foundations (F): safety and platform, before the features that lean on them

| Id | Task | Delivers | Owner | Size | Gate | Dep |
|---|---|---|---|---|---|---|
| F1 | SOP idempotent customer create (key stored with request hash in the same transaction; replay returns the same Customer; a refused request spends no key); ER sends `ER-guardian-{id}`, tolerant retry on an unreadable 2xx, request and connect timeouts | PL-FEE-5, R-5 | SOP, ER | M | | design note Part 1 (cleared) |
| F2 | EA industry route; SOP's school rule replaces `SOP_ER_COMPANY_IDS`; **data fix**: list real school Companies and correct their industry; switched on only when CM says | PL-FEE-2 prerequisite, R-1 | EA, SOP, CM | M | ⚑ | design note Part 1 (cleared) |
| F3 | ER error body to `{error, detail}` (WEB briefed first), consistent across routes | spec inconsistency (EA SPUTO 2.7) | ER, WEB | S | | |
| F4 | Contract fixtures for the two routes EA reads (`POST /schools`, `PUT /schools/{id}/first-admin`) and ER's strict decode of SOP's customer fixtures | contracts | ER, EA, SOP | S | | fish-contracts exists |
| F5 | **Audit every state-changing ER route for retry-safety** (admissions steps, enrolment, fee-schedule save, staff and device changes, class transfers); list gaps; fix the ones that can double-apply | foundations rule | ER | S to M | | |
| F6 | **Roles-and-access screen under School Administration** plus a **capabilities read** `GET /schools/{id}/me` (what this person may do here) so WEB hides what would 403; the "no teacher or bursar yet" hint | PL-SET-3, UC-E1, UC-E11 | ER, WEB | M | ⚑ | |
| F7 | **Form master** as a teacher assigned to an arm (an arm-scoped assignment, not a new global role) | PL-CLS-3, C3 | ER | S to M | ⚑ | F6 |
| F8 | **Safeguarding access**: the admin alone loses it; break-glass with reason, time limit and an alert; the safeguarding and pastoral leads and head teacher keep it | PL-SAF-1, C2 | ER | S | ⚑ | **D13** (Femi) |
| F9 | Audit extension: log exports, permission changes, score changes after locking, payment actions, views of restricted records; kept six years (proposed) | PL-AUD-1, PL-RPT-4 | ER | M | | |
| F10 | **Privacy model**: lawful basis per data category, consent records (what, when, how, who), retention schedule per record type, field switches per school and country | PL-PRV-1, 2, PL-CON-5, PL-ENR-3 | ER | M | | |
| F11 | ****Offline mobile app** design pass** (WEB and ER together): the on-device store, sync queue, conflict rule per entity, the late-sync deadline (D4), device wipe; output is a design doc, then F12 | PL-ATT-2, Part 2 section 5 | ER, WEB | S | | D1 (decided: online and an offline mobile app), **D4** |
| F12 | Offline mobile app for the **attendance register**, then **mark entry** (server side exists: devices, change feed, push ledger) | PL-ATT-2, PL-ASM-3, UC-E4, UC-E5 | WEB, ER | L | | F11 |

### Core student and family (C)

| Id | Task | Delivers | Owner | Size | Gate | Dep |
|---|---|---|---|---|---|---|
| C1 | Student master: date of birth, bio-data, admission number format, duplicate **warning**, sensitive identifiers masked | PL-ENR-1 to 4 | ER | M | | F5, F10 |
| C2 | Health summary (restricted view) | PL-ENR-5 | ER | S | | C1 |
| C3 | Contacts model: many contacts per student and the reverse, phones, priority, custody, fee payer, communication preference; migrates the embedded guardian list | PL-CON-1 to 3, 5 | ER | L | | C1, F10 |
| C4 | Court-order and contact-restriction flags (restricted detail, blocks release and pickup) | PL-CON-6 | ER | M | ⚑ | C3, F8 |
| C5 | Student photograph with consent | PL-ENR-8 | ER | S | | C1, F10, D2 |
| C6 | Create controls and lists in WEB for admissions, students and timetable using the school vocabulary | PL-ADM-2, PL-CLS-6 | WEB | M | | |
| C7 | Offer-letter generation stored as a document | PL-ADM-3 | ER | S | | D2 (documents) |
| C8 | School structure: levels per country pack, streams, subject catalogue and combinations; configuration packs per country | PL-CLS-1, 4, PL-SET-2 | ER | L | | |

### Assessment completion (A: the product's core; S1 A4 to A7)

| Id | Task | Delivers | Owner | Size | Gate | Dep |
|---|---|---|---|---|---|---|
| A1 | **Approval chain and locking** (configurable; changes after locking need approval and are audited) | PL-ASM-4 | ER | M | ⚑ | F7, F9, **D3** |
| A2 | Totals, averages, subject and class positions (switchable off), highest, lowest, average per subject | PL-ASM-5 | ER | M | | A1 |
| A3 | Affective and psychomotor ratings; comments | PL-ASM-6 | ER | S | | A1 |
| A4 | Report-card templates and PDF; broadsheets; batch generation in the background | PL-ASM-7, 8 | ER, WEB | L | | A2, A3 |
| A5 | Promotion, repeat, probation by configurable criteria; head-teacher approval; preview and reversal | PL-ASM-9, PL-IMP-1 | ER | M | ⚑ | A2, **D11** |
| A6 | SPI and TPI (formulae blocked, O1) | PL-ASM-10 | ER | M | | Femi's formulae |

### Attendance completion (T)

| Id | Task | Delivers | Owner | Size | Gate | Dep |
|---|---|---|---|---|---|---|
| T1 | Absence reasons, lateness time, **correction with a reason** (original and audit kept) | PL-ATT-3 | ER | S | | F9 |
| T2 | Chronic and consecutive-absence alerts; attendance summaries | PL-ATT-6, 7 | ER | M | | T1, N1 |
| T3 | Form-master approval of the register (delegable) | PL-ATT-8 | ER | S | | F7 |

### Fees through SOP (M: after F1, F2 and Finance's answers)

| Id | Task | Delivers | Owner | Size | Gate | Dep |
|---|---|---|---|---|---|---|
| M1 | **Tax treatment on each fee-schedule item, per country and per period** (Femi 2026-10-13: "Tax rules depend on countries and on periods"): the item carries a **tax class** (tuition, boarding, exam fee) and a short list of **effective-dated category entries** (from, to, category), and the invoice **resolves the category from the supply date** (the Irish VAT effective-dating `asOf` lookup is the precedent); a date with no entry **refuses the invoice**, never a default; Finance sets the entries, with audit; an interim that is removed when IM's service item carries the same effective-dated category (IM asked; no category logic of our own that must be unpicked later) | PL-FEE-1 | ER | S to M | | D6 decided; IM and GL to confirm the shape |
| M2 | **T-ER3**: a parent's "paid" is a claim that triggers verification; the fee desk verifies; held until after the sitting | PL-FEE-3, UC-E8 | ER | M | | F5 |
| M3 | SOP opts in `POST /api/sales`; ER **raises the credit sale** with key `ER-invoice-{id}`, **issuer = the school (organisation) through its finance department**, term dates and student reference (the person who acted stays in the internal audit trail only, never on the invoice); ER stores only the mapping | PL-FEE-2, 4 | SOP, ER | L | ⚑ | F1, F2, M1, SOP issuer field |
| M4 | SOP opts in the collection route; ER **records a verified payment** with key `ER-payment-{id}`; the payment goes to **the school's settlement accounts** (the Company's, per the cash-book design: cash book for cash, a settlement account for bank transfer and the like); SOP and GL confirm how a collection names the account | PL-FEE-3 | SOP, ER | M | ⚑ | M2, M3, SOP and GL settlement-account answer |
| M5 | Re-point statements, guardian outstanding and parent summary at SOP (gross, including VAT; label changes; WEB told first); retire the invoice amounts and status in ER and `confirmPaymentStub` | PL-FEE-6, 4 | ER | M | | M3, M4 |
| M6 | Receipts shown and sent from SOP's numbering | PL-FEE-7 | ER, SOP | S | ⚑ | M4 |
| M7 | Scholarships and waivers (eligibility and approval here; the credit is posted by SOP and GL once **request Q3** exists: a waiver known before invoicing is just a smaller net line and needs nothing) | PL-FEE-9 | ER, SOP, GL | M | ⚑ | M4, Q3, **D8** for clearance |
| M8 | Clearance policy | PL-FEE-10 | ER | M | ⚑ | **D8** |

### Communications, documents, staff, portal, reports, privacy (N, K, S, P, R, V)

| Id | Task | Delivers | Owner | Size | Gate | Dep |
|---|---|---|---|---|---|---|
| N1 | **Notifications port** (generic, **D2**) and SMS adapter with delivery status and cost; blocked on the SMS account | PL-NOT-1 | ER (generic port) | L | ⚑ | D2, SMS account |
| N2 | Templates with merge fields and languages; bulk by arm, level, fee status; **no sensitive data** at compose; opt-out honoured | PL-NOT-2, 3, PL-CON-2 | ER | M | | N1, C3 |
| N3 | Staff alerts with role routing; safeguarding alerts to the safeguarding group only | PL-NOT-4 | ER | S | | N1, F8 |
| K1 | **Documents port** (generic, **D2**): attach, version, retention tag, allow-list, size limit, malware scan | PL-DOC-1, 2 | ER (generic port) | L | ⚑ | D2, F10 |
| S1 | **Teaching record** (subjects, arms, registration with expiry, vetting, training) with restricted vetting view | PL-STF-1 to 3 | ER | M | ⚑ | F6, **D12** |
| S2 | **Employ once through HR** (the push now carries `division` and a default duty, see D22; the EA role is D23), as already drafted by EA and ER (`EA_Teaching_Staff_Onboarding_EA_Half_Draft.md`): the Owner Admin employs in HR; HR pushes one command to EA; EA creates the invite and **pushes to ER** `PUT /schools/{schoolId}/staff/{email}/employment` (employmentId, TEACHER duty only, dates, version) and an end route on dismissal. **ER never calls HR**; it holds the teaching record plus the employmentId. New inbound service-account route. Open blocker: which EA Role a teacher holds (EA's Role enum has no teacher value; adding one is consumer-first and only GL decodes it strictly) | PL-STF-5 | ER, EA, HR | M | ⚑ | S1, EA Role answer |
| S3 | **Staff by division**: HR adds a **division** (Operations, Administrative, Finance) to the employment; EA's push to ER carries it; WEB shows each division's staff inside the existing three tabs from a read-model joining HR, EA and ER on email (a person appears in every division where they hold a role, payroll in the primary one; the Proprietor above the divisions); ER gives a teaching record to Operations staff only | PL-STF-8 | HR, EA, ER, WEB | M | | S2, F6, HR reply, **D20, D21** |
| S4 | **Payroll split by permission**: HR holds the **pay basis** on the employment record (time, piece, contract or salary); permissions set pay basis (Administrative), run payroll and approve a pay run (Finance), separate, the preparer not the approver; the Payroll screen under School Finance, the basis field under School Administration; HR and EA confirm today's record and run/approve split | PL-STF-9 | HR, EA, WEB | M | ⚑ | S3, HR reply |
| P1 | Guardian per-child read API completed (results, attendance, timetable, fees via SOP); custody and restriction enforced | PL-PRT-2, 3 | ER | M | | C3, C4, A4, M5 |
| P2 | Guardian sign-in with phone and one-time code. **Not an EA build** (guardians are not EA Users). Three parts: the user pool and SMS sending for the code (CM; general SMS is parked, only the Cognito verification path was used), the sign-in screen (WEB), and **ER maps a token to a guardian by phone claim instead of email** | PL-PRT-1 | CM, WEB, ER | M | ⚑ | N1 or Cognito SMS, D15 |
| P3 | Guardian portal screens (login, children, results, attendance, fees, claim a payment) | PL-PRT-2 to 3 | WEB | L | | P1, P2 |
| R1 | Search (name, admission number, guardian phone) and standard reports (class lists, attendance, fee collection, defaulters, staff lists) | PL-RPT-1, 3 | ER, WEB | L | | C1, T2, M5 |
| R2 | Exports to PDF, CSV, Excel, **logged**, same field restrictions as on screen | PL-RPT-4 | ER | M | ⚑ | F9 |
| R3 | Bulk operations with preview, log and reversal; spreadsheet migration with reconciliation report | PL-IMP-1, 2 | ER | L | | C1, F5 |
| V1 | Data-subject requests and the retention disposal review; DPIA pack (inventory, sub-processors, security notes) | PL-PRV-3, 4 | ER | M | | F10, **D9** |

### Phase 2 and 3 (named, sized roughly, scripted when scheduled)

| Id | Task | Owner | Size | Gate |
|---|---|---|---|---|
| X1 | External exams: bodies, series, registration, index numbers, CA export, results, certificates (formats are owned research) | ER | XL | ⚑ |
| X2 | Boarding: hostels, exeat, visiting days, sick bay (restricted), roll call | ER | XL | ⚑ |
| X3 | Gate and visitor log, pickup verification, evacuation lists, incident workflow, suspensions | ER | XL | ⚑ |
| X4 | WhatsApp adapter and SMS fallback; bulk approval thresholds | ER | L | |
| X5 | Offline cash receipting from pre-allocated number ranges (needs a SOP design) | ER, SOP | L | ⚑ |
| X6 | Statutory returns per country (Nigeria first, then Sierra Leone, Liberia): **each starts as a research task** obtaining the format with a local partner | ER | L per country | ⚑ |
| X7 | Group view across a Tenant's schools: **no EA build** (`GET /api/me` already lists the Tenant's school Companies); WEB lists them and calls ER per school with the caller's token, each read per Company; a group head must hold an assignment in every school; no cross-school aggregate until the pseudonymised export (P3) | WEB | M | ⚑ |
| X8 | Online and mobile-money payment channel (a platform integration SOP does not yet have) | SOP | XL | ⚑ |
| X9 | Houses, prefects, entrance exams, student login, analytics, Ghana, Gambia, Guinea, Côte d'Ivoire and UK packs | ER | XL | |

Notes from POP (2026-10-13) that bear on X1 and X2: **paying an exam body is an ordinary POP purchase** (the body is a Supplier, the fee a PO line with an explicit VAT category), but POP pays only **after a match**, so a fee paid **in advance** of any invoice is a **prepayment that POP does not have** (new POP scope, to be raised with CM early); boarding supplies are generic POP plus IM, with one **known fault until GRNI is built** (a stock purchase received in IM and matched in POP counts AP and cost twice), so do not promise boarding stock accounting as correct before GRNI is live; a school bursar who buys needs the **POP module granted at the school's Company**, and whether the Education industry enables it by default is unchecked (EA has answered: there is **no industry default**; see D18).

### Requests to the generic services (Q): logged as requests to SOP and GL, **not ER workarounds**

From GL (2026-10-13, verified in GL code, master 743e418): ordinary tuition and fee invoices with per-line VAT category, part payments, collections into any cash or bank book, returns without VAT, balances and aging per guardian **all work today**. These six postings a school needs **do not**:

| Id | Request | Today | Needs |
|---|---|---|---|
| Q1 | **Deferred tuition income released over a term** | `record-sale` posts to revenue at once; no deferred-income account or release schedule (IFRS 15 over-time is unbuilt) | a deferred-income account in the chart template, a sale posted to it, a scheduled release; an accountant's release rule (monthly, by term days) ; **Femi 2026-10-13: recognise on the invoice day for now, spread over the term before Live**; the release rule (monthly or by term days) is still the accountant's (D17) |
| Q2 | **Pass-through fees for exam bodies** | not cleanly expressible: no payable-to-third-party discovery, no remittance posting | a pass-through sale and its remittance; VAT decided; an accountant's **principal-or-agent** rule first |
| Q3 | **Scholarships and waivers as a credit** | **Decided by Femi 2026-10-13 (GL, Decisions_Log): accountants' business-discount treatment, two accounts, Discounts Given and Discounts Received.** A credit note of kind DISCOUNT debits **Discounts Given** (accounts 4910 Given and 4920 Received, GL decision D-SR7, about 1.5 days), VAT reversed per category, after invoicing; before invoicing a sibling or scholarship discount is just a smaller net line (a trade discount, no separate entry); a scholarship **paid by a sponsor** is not a discount and **does not change the customer** (Femi, 2026-10-13: "A third party paying an invoice does not cease the legal status of a customer or Guardian"): the guardian stays the customer on the invoice and the sponsor is the **payer** of a collection applied to the guardian's invoice, held as data (payer party and reference), see Q8 | written into GL's Sales Returns Playbook, nothing built; a waiver after invoicing is a discount credit note, not a sales return (`Sales_Returns_Credit_Notes_GL_Half.md` s2.4), awaiting Femi's approval of that Playbook |
| Q4 | **Discounts taken at collection** (early payment, sibling) | **Decided 2026-10-13**: an optional discount leg on the collection, also Discounts Given | GL and SOP, with Q3 |
| Q5 | **Refund of an overpayment or a refundable deposit** | no refund route, no customer-deposit liability | a refund posting and the deposit account |
| Q6 | **Writing off unpaid arrears** | no write-off route; expected-credit-loss not reconnected | a write-off or bad-debt route |
| Q7 | **Prepayment to a supplier** (an exam body paid in advance) | not in POP | POP scope, raised with CM |
| Q8 | **Third-party payer on a collection** (a sponsor, employer or church paying a guardian's invoice) | no payer field on the collection | an additive **payer party and reference** on SOP's collection (consumer-first); what a guardian statement shows (the invoice, the payment, who paid); SOP to say where the payer lives and what the statement shows |

GL offers to write its half of Q1 and Q2 first, once an accountant has answered the release rule and the principal-or-agent question. None of these blocks the first fee build: the first term raises at term start without Q1, and exam fees, waivers, refunds and write-offs are P2.

## 2. Dependency order (what must precede what)

**Stage 0, foundations that unblock everything** (parallel where noted): F1, F2 (SOP and EA; ER's part is S), F3, F4, F5, F9, F10; then F6 and F7. F8 follows Femi's D13. F11 (design pass) runs alongside.

**Stage 1, the core student record and the product's core**: C1, C2, C3, C8 and C6 (WEB) first; then A1, A2, A3 (approval, totals, ratings), then A4, A5. F12 (offline client) runs in parallel from F11; attendance first, then marks. T1 to T3 land with F7 and F9.

**Stage 2, money**: M1 (needs D6), then M3 and M4 once F1 and F2 are switched on and SOP has opted the routes in; M2 (T-ER3) before M4; then M5, M6; M7 and M8 wait for D8.

**Stage 3, communication, staff, portal, reports**: N1 to N3 (need D2 and the SMS account); K1 (documents) and C5, C7 follow; S1 and S2 (need D12 and HR); P1, P2, P3; R1 to R3; V1.

**Stage 4, phase 2**: X1 to X8 in the order Femi sets (D5, D7), starting with the country pack the first pilot needs.

**Critical path to a pilot floor** (spec 10.1 and Part 1 section 9): F1, F2, F5, F6, F7, F10, then C1, C3, A1 to A5, M1 to M6, N1 to N2, T1 to T3, P1 to P3, R1, F12. The longest single chain is **offline client (F11, F12) and the SMS account**, which is why D1 matters.

## 3. Rollout, rollback and risk

- **Rollout:** each task is its own branch, consumer-first for additive changes; CM sequences and deploys; WEB is briefed before any response-shape or wording change that reaches a screen. Production data is test data until the Live switch, so breaking clean-ups (error body, mapping tables) are cheapest now.
- **Rollback:** code reverts by redeploying the previous image; migrations are additive and forward-only (a rollback is a new migration). The SOP-through-ER switch (F2, M3) is an off-switch: unset the service audience and every ER token is refused.
- **Risks:** (1) the offline client is the largest unknown and is WEB-heavy; (2) SMS is blocked on an external account; (3) statutory formats are unobtained; (4) revenue timing for tuition is an accounting decision that can force a change to M3; (5) the children's-data rules need counsel before a real school; (6) sizes are estimates and unproven; (7) one engineer-session per service, so stage 1 and stage 2 compete for the ER session: sequence rather than parallelise.

## 4. Tests and acceptance per stage

Stage 0: contract fixtures decode through strict clients; a replayed customer create returns one Customer; a refused call spends no key. Stage 1: the UAT scripts UC-E2 to UC-E6 pass on a low-cost Android device, offline for the register and marks, with a three-day offline run and a sync that loses nothing. Stage 2: UC-E7 and UC-E8 end to end on a test school, SOP and GL balances agree with ER's statement, a retried invoice or payment creates one. Stage 3: UC-E8 to UC-E14. Every ⚑ has CM's recorded review before its build.

## 5. What can start the moment Femi approves

F1, F3, F4, F5, F9, F10, F11 (design only), C1, C6 (WEB). Nothing that touches an RBAC, service-account, cross-Tenant, export or authentication gate starts until CM has reviewed it.

## 6. Consolidated decisions for Femi (one batch, asked once, each with a recommendation)

Items **already put to Femi through CM** are marked **(with CM)**; they are listed so the batch is complete.

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| **D1** | **Pilot shape** | **Decided 2026-10-13 (Femi): "Both. Offline is an App on a mobile device."** Plan for **online** use and an **offline mobile app** together; WEB's separate-app SPUTO decides the technology | F11, F12 |
| **D2** | **Notifications and documents**: generic platform services (other runtimes need them) or built inside ER first | generic ports, first implementation in ER | N1, K1, C5, C7 |
| **D3** | **Who approves test marks** (form master is not the default) | head of department, then head teacher; configurable per school **(with CM)** | A1 |
| **D4** | **Late-sync deadline** for offline marks and attendance | a per-school setting, conservative default **(with CM)** | F11 |
| **D5** | **First country pack**: Nigeria (the spec's reference) or Sierra Leone (the Mano River arrowhead) | choose one for the first pilot; the exam and census packs differ | C8, X6 |
| **D6** | **Tuition VAT, income recognition, issuer, settlement** | **Decided 2026-10-13 (Femi)**: VAT follows the **country and the period** (effective-dated, never a default, see M1); income is recognised on the **invoice day for now and spread over the term before Live**; the invoice **issuer is the school (organisation)** through its finance department, the person only in the internal audit trail; payments go to **the school's settlement accounts** | M1, M3, M4 |
| **D7** | **Boarding in the first phases?** | no, phase 2, unless the pilot school boards | X2 |
| **D8** | **Clearance policy**: may a school withhold report cards or transcripts for unpaid fees | no default; needs counsel and a per-country rule; never blocks attendance, safeguarding or medical | M7, M8 |
| **D9** | **Contracting entity and processor role** for children's data (UK or Irish company), DPO and regulator registration | needs counsel before the first paying school | V1, go-live |
| **D10** | **Statutory returns**: who obtains the formats from local partners, per country | a named country lead; ER specifies and builds | X6 |
| **D11** | **Rankings and promotion defaults** | positions off by default and school-configurable | A2, A5 |
| **D12** | **Staff: employ once through HR**, ER keeps only the teaching record | yes | S1, S2 |
| **D13** | **Safeguarding access: should the school admin alone lose it** (the spec says admins must not automatically have it; the code gives it) | yes; the safeguarding and pastoral leads and head teacher keep it; break-glass is logged | F8, UC-E9 |
| **D14** | **Student writes: when does the admin lose them?** (decided: they stay until a registrar exists) | at the dev-to-Live switch, after the Staff-and-roles screen ships | F6 |
| **D15** | **Guardian sign-in in P1**: phone and one-time code (the user pool and SMS are CM's, the screen WEB's, the token-to-guardian mapping ER's; **not EA**: guardians are not EA Users and EA advises against making them so) or a simpler first channel | P1 if SMS or Cognito's phone path is available; otherwise keep email sign-in for the pilot | P2, P3 |
| **D17** | **Accounting rules for a school** (an accountant's, Femi to name who): how tuition income is released over a term (Q1), principal or agent for exam fees (Q2), (a waiver is **decided**: Discounts Given, see Q3 and Q4) | take the first term at term start; get the rules before exam fees and waivers (P2) | Q1, Q2, X1 |
| **D19** | **Is a sponsor's pledge before payment its own receivable?** (a sponsor promises to pay a pupil's fees; until the money arrives, is that a receivable from the sponsor, a note, or nothing at all, the guardian staying liable for the invoice) | nothing in the ledger until paid: the guardian stays the debtor, and the pledge is a record in ER that can later be applied as a payer on a collection; revisit if schools want sponsor aging | Q8, M7 |
| **D18** | *Superseded by D22 and D23 below (EA's answer after the division decision).* | | |
| **D20** | **Where do supporting staff sit** | **Decided 2026-10-13: Operations** | S3 |
| **D21** | **Where does payroll sit** | **Decided 2026-10-13 (Femi): both**: the **pay basis** (time, piece, contract or salary) is Administrative and set under School Administration; the **pay run** given a basis is Finance; separate permissions (RBAC): set pay basis, run payroll, approve a pay run, the preparer not the approver; **permissions proposed in the Staff area doc, for CM and HR/EA to confirm** | S3, S4 |
| **D22** | **Default duty from the division** pushed by EA | OPERATIONS maps to TEACHER; ADMINISTRATIVE and FINANCE map to no duty (a registrar, bursar or fee officer is a deliberate grant, never implied) | S2, S3 |
| **D23** | **An EA role for a person who works only in the Education Runtime** | one generic role STAFF, added consumer-first; Owner Admin adds ACCOUNTANT where ledger access is needed | S2 |

Already decided and not asked again: Enrolment (British), Purchasing, Stores, Accounts, Surplus, Income and Expenditure, Income; no duplication of SOP; per-Company RBAC; admin read-only on student records and finance; one school per Company; PARENT as an alias of GUARDIAN.

## 7. Contributors' replies (filled as they arrive, before CM presents the batch)

| Contributor | Asked | Reply |
|---|---|---|
| SOP | route opt-ins, keys, failure mapping, "raised by", cash account, receipt numbers, payment channel | pending (asked 2026-10-13) |
| EA | guardian sign-in, group views, MFA timing, HR link | **replied 2026-10-13**: provisioning and first-admin confirmed (idempotent; EA also grants the Owner Admin as first admin of every school Company); guardian OTP is **not** an EA build (CM, WEB, ER); group views need no EA build (`GET /api/me`); MFA is a Live-switch item, and school staff are ER staff assignments so enforcement is pool-wide or an ER token check (unverified); **HR link corrected**: HR pushes to EA, EA pushes to ER, ER never calls HR (applied to S2); industry route live (EA :95) |
| HR | the employ-once flow, fields held | **replied 2026-10-13** (HR master 370ccbc), see the facts below |
| GL | nothing needed in P1 and P2; any posting SOP cannot express | **replied 2026-10-13**: nothing needed either way; six postings logged as requests Q1 to Q6 |
| IM | **replied 2026-10-13**: ER has no IM access and needs none; the tuition VAT category will become an IM service item per fee type with ER storing its id later; ER keeps an explicit category until then; **ER must never set a category by machine** (a tax-affecting choice needs a human) | received |
| POP | nothing needed | **replied 2026-10-13**: confirmed; flags on advance payment (Q7), GRNI before boarding stock, and POP module access (see X1/X2 notes) |
| WEB | offline client feasibility, screens per area, low-data mode | pending |

## 8. After approval

CM presents this batch once. On approval, each task gets its coordination row and its branch; tasks that need a gate go to CM first; WEB and the generic owners are briefed per stage. This Playbook is then the index that the operator sheet (`ER_School_Playbook_Draft.md`) links under PLAYBOOK CONTENTS, and it is kept honest: updated in the same change as the code it describes.

## 9. HR's facts (the reply recorded in section 7) (reply of 2026-10-13, from HR master 370ccbc; nothing built, nothing promised)

- **What HR holds** (an Employee is one employment of one person at one Company): id (usable as the employmentId), companyId, name, email (**optional**, unique per Company), bank details (encrypted, owner-only), employment type (SALARIED, HOURLY, UNPAID), pay (rate and pay frequency), standard working days, contracted hours per day, start date, end date (**the exit date**). **HR does not hold:** staff number, department, campus, next of kin, phone, address, job title, registration, vetting, a division or any staff kind. **HR will not hold** registration or vetting; the Education Runtime owns the teaching record (PL-STF-2, 3). So the Education Runtime keeps everything in the spec's staff profile except the start and exit dates.
- **The push in PL-STF-5 does not exist.** HR has **no outbound command to EA**: it only forwards the signed-in person's own token for the roster and invite proxy, has **no service login**, and **no inbound service route**. It needs a new HR service credential for EA (CM's lane), a gateway, and triggers on create, change and end; and **an employee must have an email to be pushed**. Task S2 therefore carries three new dependencies: the credential (CM), the HR gateway and triggers (HR), and a rule for employees with no email (required at employ time for a school Company, or not pushable).
- **Division (S3):** HR can carry one closed-value field (OPERATIONS, ADMINISTRATIVE, FINANCE): a migration (nullable column with a CHECK on the three values), an optional field on create, update and responses (WEB and EA declare it first), about **0.5 day** plus the wire coordination. **Existing employees: NULL means "not set"**, never a guessed default; the push sends it only when set. One **primary** division per employment; a person in two divisions by duties is an Education Runtime and EA grant, not HR. Held until CM says go.
- **Pay basis (D21, S4):** today the basis is the employment type. There is **no piece-rate, contract or commission basis**; adding one is a new value plus pay semantics (a change to the constraint on pay completeness), about **1 day plus WEB**. Femi's "contract (salary)" is today's SALARIED.
- **Run versus approve:** separate today. Submitting a pay run needs write access at the Company with the HR module (a payroll officer); **approve, reject and retry are Owner-Admin only**, and the run posts to GL only on approve. **Not enforced:** the preparer is not the approver (the Owner may submit and approve the same run); HR records submittedBy and decidedBy, so the rule is **one extra check and a 409**. Moving approve to a Finance permission instead of Owner-only touches the Owner check on the approve, reject and retry routes, EA's grant model, WEB's approve controls and tests: an RBAC change, frozen until CM reviews (E1 in the deferred-enforcement list, Part 2 section 1.1).
