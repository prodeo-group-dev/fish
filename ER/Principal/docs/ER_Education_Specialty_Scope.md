# What only a school needs: the Education Runtime's specialty scope (SPUTO: scope, findings, order)

**Status: DRAFT 1, 2026-10-07. Analysis and proposal only; nothing built, nothing decided.** Femi's instruction: *"You are to focus on the specialty requirements of the education industry that the generic FiSH cannot handle."* and, in the same breath, *"Collaborate with WEB as he does all the UI/UX for FiSH and its Runtimes. You are the Education Runtime called EduSys."* This document sorts every Education Runtime requirement into what is genuinely education-specific and what generic FiSH already does or should do, checks the code against it, and proposes where the Education Runtime's effort should go. Facts are tagged **[spec]** (the v0.1 requirements), **[code]** (read from `fish-education-runtime` on 2026-10-07) or **[backlog]**.

## 1. The rule used

Per the product statement (`docs/FiSH_Product_Description.md`): FiSH on its own is the Enterprise Runtime; a specialist runtime **inherits all of FiSH and adds what its industry needs**. So the test for any capability is:

- **Specialty (the Education Runtime owns it):** the *data or the rules* exist only because it is a school: terms and arms, continuous-assessment weights, grading scales, promotion, exam bodies, statutory attendance codes, child protection, boarding, custody and pickup, state/LGA bio-data, teacher registration.
- **Generic (consume FiSH, do not build):** any organisation needs it: billing, payments, receipts, general ledger, HR and payroll, document storage, messaging infrastructure, identity and access, audit, import infrastructure, multi-tenancy, offline device infrastructure.
- **Mixed:** a generic mechanism carrying education rules. The mechanism comes from FiSH; the Education Runtime supplies only the rules and the screens that apply them.

The spec's own boundary table (section 2.3) already draws the money line this way: the Education Runtime owns fee *rules* and clearance *policy*; FiSH owns invoices, payments, receipts, balances and posting. **[spec]**

## 2. Classification of every requirement family

| Family (spec) | Verdict | Generic FiSH provides | The Education Runtime's specialty part | Built today **[code]** |
|---|---|---|---|---|
| **ER-ASM** assessment, report cards, promotion (11) | **Specialty, the core** | nothing | CA components and weights per level and term, grading scales per country, teacher-to-form-master-to-principal approval and result locking, totals, positions and rankings, affective and psychomotor ratings, report-card and cumulative templates, broadsheets, promotion/repeat/probation rules | **Thin.** A grade is one text value per student, subject and term; there are no scores, weights, scales, positions, ratings, report cards, broadsheets or promotion. SPI/TPI formulae are blocked on a decision. |
| **ER-CLS** school structure (8) | **Specialty** | tenancy only | sessions and three terms, levels per country, arms, senior streams and programmes, subject catalogue and student subject combinations, houses, prefects, multi-campus templates | Terms, rooms, lessons, teacher-subject assignments, a flat class-section list. **No streams, subject combinations, houses, prefects or multi-campus templates.** |
| **ER-ENR** enrolment and records (10) | **Specialty** | identity, document attach | admission workflow with entrance exam/interview, admission-number format, duplicate detection, state/LGA, religion (sensitive), national IDs masked by default, health summary (blood group, genotype, allergies, consent), withdrawal/transfer with clearance checks, effective-dated history | A pipeline with offer and accept/decline, one-application-per-year guard, student register with audit, CSV import/export. **No admission numbers, bio-data fields, national IDs, structured health summary, withdrawal/transfer record, or entrance exam.** |
| **ER-ATT** attendance (9) | **Specialty** | offline infrastructure | statutory mark codes, morning/afternoon and per-lesson registers, absence reasons, chronic-absence thresholds, same-day parent notice, report-card and census summaries, correction-with-reason | Nine-code mark table, replace-on-remark, device capture, server side of offline sync. **No read-back or reports, no alerts, no reasons or lateness time, no correction history.** |
| **ER-SAF** safeguarding (9) | **Specialty, highest sensitivity** | audit, RBAC | child-protection records and referral pathways, incident reporting with escalation timestamps, gate and visitor log, pickup verification, evacuation lists, missing-student workflow, suspensions and expulsions | Field masking and an access log for safeguarding notes only. **None of the workflows.** |
| **ER-CON** guardians and contacts (8) | **Specialty** | identity | multiple contacts per student and several students per contact, custody and legal-guardian status, court orders and contact restrictions, authorised pickup persons | One embedded guardian list per student. |
| **ER-EXM** external exams (12) | **Specialty** | none | WAEC, NECO, BECE, NABTEB and their francophone equivalents: registration, index numbers, CA export to the body's format, results, certificate tracking, verification | **Nothing.** |
| **ER-BRD** boarding (6) | **Specialty** | none | hostels, rooms, beds, exeat, visiting days, sick bay, roll call | **Nothing.** |
| **ER-STF** staff (7) | **Mixed** | **HR owns** employment, pay, contracts | teaching-specific records only: subjects and arms taught, teacher registration (TRCN, NTC, TSC), vetting and safeguarding checks, expiry reminders | Roles only (`StaffAssignment`) and a teacher directory. Onboarding is being designed with HR and EA. |
| **ER-FEE** fees (14) | **Mixed; mostly generic** | **SOP and GL own** invoices, payments, receipts, numbering, balances, posting, multi-currency, reconciliation | fee structure *selection rules* (level, stream, boarding, term), scholarship and bursary **eligibility and approval**, the **clearance policy** with its safeguards | An invoice and payment stub that **never reaches SOP or the ledger**; being replaced by Epic 13. |
| **ER-PPT** parent portal (7) | **Mixed** | identity, messaging, payment session | what a guardian may see (attendance, results, balance) under custody rules | A basic gateway: attendance, released grades, invoices. |
| **ER-RPT** reporting (8) | **Mixed** | search and reporting engine | census and ministry exports in the mandated formats, school analytics | CSV export of the register only; census formats are blocked on a missing format specification. |
| **ER-DOC** documents (8) | **Mostly generic** | storage, versioning, retention, scanning | education document *types* (birth certificate, transfer letter, testimonial), transcripts and testimonials with a verification code | **Nothing**; no object storage in this service. |
| **ER-NOT** messaging (7) | **Mostly generic** | gateway, templates, delivery | which school events notify whom, and the rule that sensitive data never goes in an SMS | **Nothing**; SMS is blocked on account set-up. |
| **ER-IMP** import/export (6) | **Mostly generic** | import infrastructure | the student and staff templates, census formats | Student CSV import and export only. |
| **FIN-INT** (20) | **Generic integration** | SOP, GL | the connector and the rules above | The write side of an outbox; no delivery (BK-FIN-12). |
| **NFR-OFF** offline, **NFR-SEC/PRV** | **Generic mechanisms, specialty rules** | device trust, sync, encryption, audit | which education entities work offline, children's-data rules | Device trust and sync server side exist (built here, see section 3). |

## 3. Findings

1. **The school-specific core is almost entirely unbuilt, and the backlog hides it.** The most education-specific families, ER-ASM (11 requirements, nearly all *Must*), ER-CLS streams/subjects/houses, ER-ENR admission numbers and bio-data, ER-EXM and ER-BRD, have **no backlog rows** or a single placeholder row, while the effort of the last weeks went into generic work: billing identities, invoice stubs, device trust and sync, and cross-service plumbing. The backlog's Epic 5 stops at BK-ASS-1..7, which cover grade entry, publishing, and the blocked SPI/TPI formulae. **[backlog, code]**
2. **The one thing that makes this a school product is the assessment cycle** (scores, weights, scales, approval, report cards, promotion). A school cannot run a term on the current single-text-grade model. It is also the least dependent on any other service. **[spec, code]**
3. **Generic work already inside the Education Runtime** (candidates to hand over or stop extending):
   - **Fee invoicing and payment confirmation:** the target is SOP (Epic 13); extend nothing here.
   - **Guardian billing identity** (`GuardianAccount`): a generic customer link, already SOP's concept.
   - **Device trust and offline sync** (`RegisteredDevice`, delta-pull, idempotent push): a **generic offline capability** any FiSH module could use (a shop-floor stock count, a clinic). It was built here because attendance was first. **Recommendation: leave it in place until a second consumer exists, then promote it.** Do not extend it with more school-specific logic.
   - **Rooms, document storage, messaging, import:** generic mechanisms; use FiSH's when they exist, add only the school rules.
4. **Epic 13's Education Runtime share should be kept to the education rules and a thin connector**, not a second billing system: fee-structure selection, scholarship eligibility and approval, and the clearance policy. Everything else in the epic is SOP's. **[spec 2.3]**
5. **Several specialties are blocked on inputs only Femi or a regulator can supply**, not on engineering: the grading scales and exam-body formats per country, the SPI/TPI formulae (Open #1), the census formats (Open #4), and which country's variant comes first (the attendance codes were adopted as UK-style by direction, 2026-09-22, while the market is Nigeria). **[backlog]**

## 4. Proposed focus and order (specialty-first)

Ordered by how much of a school's term each unlocks, and by what it depends on.

| Wave | Specialty work | Why this order | Needs from outside |
|---|---|---|---|
| **S1** | **Assessment cycle:** score structure (CA components and weights per level and term), grading scales, score entry with range validation and deadlines, approval workflow and result locking, totals and averages, positions (switchable), affective and psychomotor ratings | The core of a school term; no dependency on other services | Grading scales and a score structure from one real school (Femi) |
| **S2** | **Report cards, broadsheets, promotion/repeat/probation** | Consumes S1; what a parent and a principal actually receive | Report-card templates from a real school |
| **S3** | **School structure:** sessions and terms already exist; add streams and programmes, subject catalogue and student subject combinations, houses, prefects | Feeds S1 (subjects per student) and S2 | The Nigerian 2025/26 curriculum structure as data |
| **S4** | **Student record depth:** admission-number format, bio-data (state/LGA, language, previous school), national IDs masked by default, structured health summary, withdrawal/transfer with clearance, effective-dated history | Required for any real enrolment | Per-country field lists |
| **S5** | **Attendance depth:** read-back and registers, reasons and lateness, chronic-absence alerts, report-card and census summaries, correction history | The attendance register work already scoped with WEB | Femi's D2/D4/D6 |
| **S6** | **Safeguarding workflows:** guardians and custody (CON), pickup persons, gate and visitor log, incident reporting, missing-student, suspensions | Highest sensitivity; its own SPUTO (already required by Femi) before any build | The safeguarding SPUTO |
| **S7** | **Clearance and fee-rule layer** (the education side of Epic 13) | Consumes balances from SOP; thin | Epic 13 contract |
| **S8** | **External exams, then boarding** | Phase 2 per the MVP definition; large and country-specific | Exam-body formats; boarding schools as customers |

Generic items that **keep their place but are not specialty work** (staff onboarding with HR/EA, the roles route for WEB, Epic 13 plumbing, CORS/outbox hotfixes) stay on the queue **behind S1** unless they block a school from using what S1 to S4 build.

## 5. Decisions for Femi

1. **Confirm the specialty-first order** (S1 assessment cycle first), or reorder.
2. **Which country's variant first** for scales, levels and exam bodies (Nigeria is the stated arrowhead; the attendance codes are UK-style).
3. **Who supplies a real school's score structure, grading scales and report-card template**, since S1 and S2 cannot be specified honestly without one. (Recommendation: one pilot school, with a past term's data as a worked example.)
4. **Is the device trust and offline sync server side to stay in the Education Runtime** until a second module needs it (recommended), or be promoted now?
5. **May the Education Runtime's share of Epic 13 be limited to education rules and a thin connector** (section 3, item 4)?
6. **Naming:** you called this session "the Education Runtime called EduSys", while the Product Description says FiSH plus the Education Runtime *is* The Principal's EduSys. Is **EduSys** the Education Runtime alone (the school-specific layer), or the whole school product (FiSH+ER)? I will use "Education Runtime (EduSys)" for the school-specific layer until you say otherwise.

## 6. Not decided or verified here

- I did not audit WEB's screens, only the backend. **[open]**
- The requirement counts come from the spec's own tables; priorities (*Must/Should/Could*) are the spec's, not mine.
- Whether SOP, HR or EA would accept the "generic" hand-overs in section 3 is for their owners; nothing was asked of them.

## 7. Working with WEB (UI and UX are WEB's; the Education Runtime (EduSys) supplies the rules and the contracts)

Femi: WEB does **all** the UI and UX for FiSH and its runtimes. So for every specialty wave the split is:

- **The Education Runtime (EduSys)** supplies the *domain*: the rules, the data, the permissions, the API contract (field shapes, errors, paging, capability codes) and a plain-language statement of the workflow (who does what, in what order, what is locked when). It does **not** design screens.
- **WEB** supplies the *experience*: layout, flow, wording, mobile and low-bandwidth behaviour, print. It tells the Education Runtime what a screen needs from the API **before** the contract is frozen, so the contract fits a real screen rather than a guess (the lesson of the attendance register scope).

| Wave | What WEB would design (not started) | What the Education Runtime provides first |
|---|---|---|
| S1 assessment | Score entry by arm and subject (online, later offline); the approval chain view; the grading-scale and score-structure set-up | Score-structure and scale model, entry and approval routes, range and lock rules, errors |
| S2 report cards | The report-card and broadsheet layouts and their **print** output (a statutory document); the promotion review screen | Computed totals, positions, ratings and promotion verdicts as data; template fields |
| S3 structure | Streams, subjects and subject-combination set-up; house allocation | Catalogue and combination validation rules |
| S4 records | Admission, bio-data and health forms (progressive and forgiving, per the non-accountant principle); masked sensitive fields | Field list per country, masking rules, duplicate-detection responses |
| S5 attendance | The teacher register (already scoped by WEB) and the office grid | The read-back, codes-as-data and class-marking routes |
| S6 safeguarding | Screens whose **visibility** is itself sensitive; no safeguarding UI before its own SPUTO | Access rules and audit |

**First step proposed:** WEB reads this document and, for S1 and S2, says what a teacher, a form master and a principal need to see and do on a phone; the Education Runtime then drafts the S1 contract against that. No contract is frozen before WEB's input, and nothing is built before Femi's go.
