# Education Runtime Playbook, part 1 of 4: Scope (S)

**Status:** DRAFT, 2026-10-13. Written by the Education Runtime (+ER) session at Femi's direction (Decisions_Log, 2026-10-12/13: "+ER should do the full SPUTO to create ER Playbook .. a comprehensive education management information system"). **Planning only. Nothing here is built, and nothing is built until Femi approves the Playbook** (standing rule). **Revised 2026-10-17** against the Decisions_Log of 2026-10-15 and 2026-10-16 and the D3 and D11 answers (what changed is listed in `docs/ER_Playbook_Review_2026-10-17.md`): the online-only banking-style app replaces the offline client, D3 and D11 are decided, and the landlord and preparation-is-not-audit principles are added. Parts land one at a time so CM can review each: **1 Scope (this file)**, 2 Plan / SRS, 3 Use cases, 4 Tasks and Order. Evidence tags: **[code]** read in `fish-education-runtime` on 2026-10-13, **[spec]** the technical specification v0.1, **[decided]** a Femi decision in the Decisions_Log or a recorded instruction, **[TBC]** not verified or not decided.

## 0. How this relates to what already exists (it does not restate it)

| Existing document | What it settles | How this Playbook uses it |
|---|---|---|
| `FiSH-ER-Education-Runtime-Technical-Req-Spec-and-Use-Cases-v0.1.md` (230 requirements, 14 use cases) | the requirements source of truth | Part 2 selects, orders and corrects against it; it is cited by requirement id, never copied |
| `ER_Education_Specialty_Scope.md` (2026-10-07) | for every requirement family: generic FiSH provides it, or it is an education specialty | adopted as the classification rule (section 3); this part updates its "built today" column |
| `Education_Runtime_MVP_Definition.md`, `The_Principal_Backlog.md` | floor versus enhancement; the epics BK-STF/CON/DOC/FIN/NOT | folded into the phasing (section 9) |
| `Education_Runtime_Local_First_Sync_Design.md`, `Local_First_Sync_Build_Plan.md` | the offline architecture decision, **SUPERSEDED 2026-10-15** by the online-only banking-app decision (kept for the server pieces already built) | section 6 |
| `ER_Credential_School_Company_Rule_Design_Note.md` (Parts 1 to 3) | how ER sits on SOP and EA, tuition through SOP | section 4 |
| `Platform_Contract_Generic_Services_And_Runtimes_SPUTO.md` (EA) | the platform contract for runtimes | section 4 |
| `School_Vocabulary_For_WEB.md` | the school words | section 8 |
| `ER_RBAC_SPUTO.md`, Decisions_Log D-ER1 to D-ER7 | roles and who may do what | section 5 |

## 1. What the Education Runtime is, in one paragraph

The Education Runtime (ER, product name **The Principal's EduSys**) is the specialist runtime that makes the generic FiSH platform a **school management information system (EMIS)**: it holds everything a school knows and decides about its students, families, staff, classes, learning and conduct, and it hands every **financial fact** to the generic services (SOP, GL) instead of keeping a second copy of money. It runs for a **school Company**, one school per Company (D-ER5), inside a Tenant that EA owns. "Comprehensive" here means the whole life of a student in a school, from first enquiry to leaving certificate, and the school's own operating loop around it (staff, timetable, attendance, assessment, conduct, communication, reporting), for secondary schools first. **[decided]**

**Who uses it** (roles are in section 5): the Business Owner and head teacher, school admin, registrar and admissions officer, teachers (including head of department, head of year and the form master), bursar and fee officer, safeguarding and pastoral leads, guardians; and one machine caller, the attendance device account.

**Where** **[spec][decided]**: Nigeria is the reference market; the Mano River countries (Sierra Leone first among them, per the existing arrowhead decision) follow, then Ghana and The Gambia; the UK is a later variant. The platform onboards SLE only across the Mano River operation (Decisions_Log, earlier-in-force); Liberian, Guinean and Ivorian currencies are documented for reference only.

## 2. Principles that bind every later part

1. **No duplication of the generic services** (Femi, 2026-10-12: "Education Runtime does not need to duplicate these services. SOP creates income"). ER owns education rules and education records; money, stock, ledger, payroll, identity and tenancy stay where they are.
2. **Generic first, specialise through the industry type** (as Education already does). A capability another runtime would also need (documents, notifications, import) is designed as a generic port even if ER is its first implementation (decision D2 below).
3. **Online-only, banking-app model** (Femi, 2026-10-15: one app for every role, "exactly like most banking apps"). The client is thin and online: no offline cache, no local database, no queue of unsynced entries, nothing of the Tenant's data stored on the device; with no signal there is no data entry. This **supersedes the 2026-10-13 local-first decision** ("We are talking about Africa", an offline app for teachers). Every call stays retry-safe (idempotency keys) because networks drop, not because the client works offline. The cost to a school with power and signal cuts is a real risk, recorded in section 10 (D26), not hidden.
4. **Children's data is the highest-sensitivity class**: collect the minimum, say why, restrict by role, log access, retain on a schedule.
5. **ER never posts to the ledger** (enforced in code, `NoDirectGlWrites`); financial effects reach SOP and GL by idempotent calls carrying a verified fact, never a claim.
6. **Authorisation is the runtime's own and per school**; a person acts only with a role the school's admin gave them. Changes to roles obey the RBAC freeze (CM first; add-a-deny is inside the carve-out).
7. **Words are the school's** (`School_Vocabulary_For_WEB.md`); **every decision is asked once** and logged in the Decisions_Log.
8. **Prodeo is a landlord** (Femi, 2026-10-15): it has no role whatsoever in a school's data, accounts or transactions; FiSH delivers GLaaS and the school is the Tenant. ER carries no Prodeo operator route that reads or edits a school's records, no screen or message sends a school to "support" for its own data, and a stuck record is recovered school-side (the head teacher or admin) or by an identical retry.
9. **Preparation is not audit, and the Owner is the final authority** (Femi, 2026-10-16 and 2026-10-13): ER prepares and calculates accurately (totals, positions, balances); the school owns the records it allows to persist and obtains its own audit; no wording implies FiSH audits or certifies a school's records; where an approval is needed, the Business Owner is the final authority. Femi decides what is parked and what needs a professional's view; ER adds no outside-adviser gate of its own.

## 3. Coverage map: every EMIS area, who owns what, where it stands

"ER owns" is the education specialty; "Generic supplies" is what ER consumes and must not rebuild (rule from the Specialty Scope). **State** is verified in code today.

| # | EMIS area | ER owns | Generic supplies | State today **[code]** | Phase (section 9) |
|---|---|---|---|---|---|
| 1 | **Admissions** | enquiry to offer to decision to enrolment pipeline, entrance exam and interview, admission-number format, duplicate rule, offer letters | document storage (offer letters, forms); messaging | **Built**: pipeline Submitted to Enrolled, offer reference only (no letter), enrolment creates the student. Not built: entrance exam, admission-number format, letters, create screen in WEB | P1 |
| 2 | **Student records** | the student master, bio-data, health summary, effective-dated history, transfer and withdrawal with clearance checks | identity (login), document attach | **Built**: profile, audit history, photo reference, DPID identity link, class transfers, CSV import and export, safeguarding masking. Not built: date of birth and bio-data fields, health summary, withdrawal workflow | P1 |
| 3 | **Guardians and contacts** | many contacts per student and many students per contact, custody and court-order restrictions, authorised pickup persons, consent records | identity | **Thin**: one embedded guardian list; a billing guardian account linked to a SOP Customer | P1 |
| 4 | **Staff records** | teaching-specific records: subjects and arms taught, registration (TRCN, NTC, TSC), vetting, expiry reminders | **HR owns employment, pay, contracts**; EA owns identity | **Roles only** (staff assignments, teacher directory, teacher-subject assignments). Onboarding "employ once through HR" designed, not built | P1 |
| 5 | **School structure** | sessions and terms, levels per country, arms, streams, subject catalogue and combinations, houses, multi-campus templates | tenancy | **Partial**: terms, class sections, rooms; no streams, subject combinations, houses or campuses | P1 to P2 |
| 6 | **Timetable and lessons** | the weekly timetable, conflict rules (simple, not an engine) | none | **Built**: lessons, rooms, teacher-subject checks, conflicts, scheduled lessons | done |
| 7 | **Curriculum** | topics, progress, schedule | none | **Built**: topics, progress, scheduled lessons, term links | done |
| 8 | **Attendance** | statutory mark codes, daily and per-lesson registers, absence reasons, thresholds, same-day notice | device accounts for gate readers; messaging | **Built**: nine-code table, marks, device capture, server side of sync (devices, change feed, idempotent push ledger; kept for retry safety). Not built: absence reasons, alerts, reports, correction-with-reason. **The offline client is dropped** (2026-10-15) | P1 |
| 9 | **Assessment, report cards, promotion** | score structures, CA weights, scales, entry, approval and locking, totals, positions, report cards, cumulative records, promotion rules | none | **Partly built (S1)**: grading scales, score structures, subject offerings, mark entry with history and idempotency, submit, per-offering totals and positions. Not built: approval and locking (nothing can leave SUBMITTED), whole-term totals, report cards, promotion, SPI/TPI | P1 (the core of the product) |
| 10 | **External exams** | registration, index numbers, CA export in the body's format, results, certificates | none | **Nothing** | P2 |
| 11 | **Fees and billing** | fee structure selection rules, scholarship eligibility and approval, clearance policy | **SOP** invoices, collections, receipts; **GL** ledger | **Interim**: ER's own invoice and payment stub that never reaches SOP; guardian to SOP Customer built; **the new design** (Part 3 of the design note) raises tuition in SOP. Statement route and guardian balances exist over ER's own tables | P1 |
| 12 | **Communications with guardians** | which school events notify whom; sensitive data never in an SMS | messaging gateway (SMS, WhatsApp), templates, delivery | **Nothing** | P1 (SMS) to P2 (WhatsApp) |
| 13 | **Documents** | education document types (birth certificate, transfer letter, testimonial), transcripts with a verification code | storage, versioning, retention, malware scan | **Nothing** | P1 core |
| 14 | **Safeguarding and discipline (LATER, country-triggered: Femi 2026-10-13 "Deprioritise safeguarding for now ... not required in Nigeria nor Sierra Leone")** | child-protection records, referral paths, incident log with escalation times, gate and visitor log, pickup verification, evacuation lists, suspensions and expulsions | audit, RBAC | **Partial**: restricted notes, flags, field masking, access log. None of the workflows | P1 (restricted notes done) to P2 |
| 15 | **Pastoral and health** | pastoral notes, sick bay, medical consents | audit | restricted notes only | P2 |
| 16 | **Boarding** | hostels, rooms, beds, exeat, visiting days, roll call | none | **Nothing** | P2 |
| 17 | **Reporting and statutory returns** | broadsheets, class lists, attendance and fee analysis, the census and ministry returns per country | reporting engine | **CSV register export and lists only**; census formats blocked on missing specifications | P1 standard reports, P2 returns |
| 18 | **Parent and student portal** | what a guardian may see under custody rules | identity, messaging, payment session | **Gateway API only** (attendance, released grades, invoices); parent screens belong to WEB and are not confirmed built | P1 basics |
| 19 | **Import and export** | student and staff templates, census formats | import infrastructure | **Student CSV in and out** | P1 |
| 20 | **School set-up and administration** | school profile, roles and staff access, devices, settings | **EA** tenant, Company, membership, provisioning | **Built (API)**: provisioning, first admin, staff roles, devices. **No Staff-and-roles screen** | P0/P1 |
| 21 | **Privacy and audit** | consent, retention schedule, data-subject requests, DPIA support | audit, encryption | **Partial**: audit history, pastoral access log; no consent, retention or request handling | P1 |

**Library, transport, cafeteria and tuck shop** are not in the first phases (section 7). School **supplies and procurement** are the generic POP/IM, shown to a school under school words, not an ER feature.

## 4. What the generic services supply, and the contracts ER obeys

- **SOP**: guardian Customer, credit sale (tuition invoice), collection (payment), receipts, balances; one idempotency key per invoice and per payment; the credential is allowed only in school Companies, checked against EA (design note Parts 1 to 3).
- **GL**: the ledger, fixed assets for school property, reports; never called directly by ER.
- **HR**: employment, payroll, leave; the staff of a school are employed once through HR (D-teaching-staff design), ER holds only the teaching-specific record.
- **EA**: Tenant, Company, Membership, school provisioning, the industry type that decides what a Company is; ER reads none of EA's runtime permissions.
- **IM / POP**: supplies and purchases for a school, shown under school words; no ER logic.
- **Notifications and documents**: no generic service exists yet; see decision D2.
- **Contract rules** (EA's platform SPUTO and the design note Part 2): every call retry-safe, strict decoding of access payloads, fixtures in `fish-contracts`, events as business facts through an outbox.

## 5. Roles at scope level (detail in Part 2)

Twelve assignable roles exist **[code]**: SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY, TEACHER, REGISTRAR, ADMISSIONS_OFFICER, TIMETABLER, FEE_OFFICER, BURSAR, SAFEGUARDING_LEAD, PASTORAL_LEAD; plus the guardian roles (GUARDIAN, with PARENT kept as an alias, **[decided]**) and the device account. The capability model is view, enter, approve, administer. Already decided **[decided]**:

| Area | Decided |
|---|---|
| Grades | teachers (head teacher, HOD, HOY included) enter; school admin alone and bursar do not; **test marks are approved by the head of department, then the head teacher, configurable per school** (D3, decided; the form master approves attendance, not test marks) |
| Fees | bursar and fee officer run the fee desk; the admin has a read-only view of student finance |
| Student records | the admin has read-only access to student records but **keeps the student writes until a registrar exists** |
| Attendance | taken by teachers and the form master (approval by the form master, delegable); the admin alone does not |
| Curriculum | written by the teaching roles; the admin reads |
| Safeguarding | restricted to the safeguarding and pastoral leads and the admin; access is logged |
| Roles | one Business Owner per Tenant; head teacher is the CEO of the school and acts with authority the Owner gives |

## 6. Connectivity and low bandwidth (the Mano River and Nigeria schools): ONLINE ONLY since 2026-10-15

**[decided, supersedes the 2026-10-13 local-first and offline-app decisions]** One app for every role, a thin online client modelled on a banking app: no offline cache, no local database, no queue of unsynced entries; only the sign-in credential may be kept, in the phone's secure store; a payslip, statement, report card or other document can be **downloaded as a PDF** (the sanctioned, deliberate copy). **[code]** the server side built for sync stays, because its claim-first idempotency ledger is what makes retries safe (marks, attendance); the offline client, the server gaps S1 to S6 (prefetch and the rest) and the late-sync deadline rule are **dropped**. What this means per area (Part 2 turns it into requirements); the classification below replaces the earlier "must work with no connection for days" table:

| Works with no connection | Queues and syncs later | Online only |
|---|---|---|
| nothing (a printed or downloaded PDF the school made earlier, such as a class list or an evacuation list, is the only offline copy) | nothing | **everything**: attendance register, mark entry, lookups, timetable, fee desk, admissions, report cards, reports, anything that raises money in SOP |

Low bandwidth still matters: paged lists, small payloads, compressed images, SMS as the guardian channel (see D25 on email versus SMS), no heavy assets. A pilot school's real connectivity is **unknown**; with online-only that is now a pilot-selection condition and a stated risk (D26), no longer a reason to build an offline client.

## 7. Out of scope (for this Playbook)

Payroll and HR performance (HR owns them); a learning management system, homework and content delivery; computer-based exam delivery and marking (record only); an automatic timetabling engine (simple timetable only); library, transport, cafeteria and tuck shop (possible later modules); biometrics beyond the optional device integration; **hiding any module** (Femi did not decide it); anything for an industry other than education.

## 8. Jurisdictions, statutory returns and data protection

| Country | Levels and exams **[spec]** | Statutory return **[TBC]** | Data protection **[spec]** | Pack |
|---|---|---|---|---|
| Nigeria (reference) | JSS1 to 3, SS1 to 3; BECE, WASSCE, NECO, NABTEB; JAMB record only | national education census (DNEMIS) and state returns: formats not in hand | NDPA 2023, GAID 2025 | P1 reference |
| Sierra Leone | JSS1 to 3, SSS1 to 3; BECE, WASSCE | ministry returns: formats not in hand | bill pending (no law in force) | P2 |
| Liberia | Grades 7 to 9, 10 to 12; WASSCE | ministry returns: not in hand | Data Protection Act signed June 2026 (recorded in the Localization doc) | P2 |
| Guinea, Côte d'Ivoire | collège and lycée; BEPC, Baccalauréat (structure TBC); French | not in hand | law of 2016 and law 2013-450 respectively | P3 |
| Ghana, The Gambia | JHS/SHS; BECE, WASSCE | not in hand | Act 843; PDPPA 2025 | P3 |
| UK, Republic of Ireland | later variant (spec Appendix B) | UK school census; Irish returns: not researched | UK GDPR and Irish GDPR | later |

**What this scope does not claim:** no statutory return format is specified anywhere in the repo, so each is an owned research task (Part 4) done with local partners, not an assumed field list. **Children's data** classes (identity, date of birth, health, safeguarding, photographs, contact, financial) each need a purpose, a restricted-by-role rule, access logging and a retention period; the current platform runs from one AWS region (London), so residency per country is a parked question (Localization Principle). The contracting entity and processor role are open (decision D9).

## 9. Phasing themes (sizes and order come in part 4)

- **P0, done or in flight:** school provisioning and first admin, role model, timetable and curriculum, attendance (online; the sync server's idempotent ledger stays), assessment set-up and mark entry (S1 A1 to A3, live as ER :100), admin-deny rules, vocabulary, the SOP customer path with its idempotency key, the schools-row and DPID-binding checks (in log mode; **not** to be enforced until Femi's readout of `docs/reports/ER_Enforcement_Readiness_Query.sql`).
- **P1, the pilot floor:** assessment approval, totals, report cards and promotion (the product's core); fees through SOP; Roles-and-access screen; guardians and contacts; staff records; student bio-data and health; documents core; messages to guardians (D25); standard reports; privacy basics (consent, retention); parent portal basics (WEB). (The offline client for attendance and marks is **dropped**, 2026-10-15.)
- **P2:** external exams, boarding, WhatsApp, statutory returns for Nigeria, Sierra Leone and Liberia packs, lesson attendance reports.
- **LATER (country-triggered), not in the Nigeria or Sierra Leone packs:** safeguarding and child-protection workflows, access rules and the safeguarding status read; brought forward when a country pack or customer requires them (Femi, 2026-10-13). What is built stays as it is: restricted notes, flags, field masking, the access log. The built-but-parked change (admin alone loses access) is on the Education Runtime branch `feature/safeguarding-admin-deny` (cf1c711) and is **not** being reviewed or released.
- **P3:** Ghana, The Gambia, Guinea, Côte d'Ivoire packs, ministry-scale deployments, analytics, UK variant.

## 10. Decisions needed from Femi (asked once, with a recommendation)

| # | Decision | Recommendation | State |
|---|---|---|---|
| D1 | **Pilot shape** | **Decided 2026-10-13 ("Both. Offline is an App"), then SUPERSEDED 2026-10-15** by the one online-only app: the first pilot is a school with confirmed workable connectivity; see D26 for the residual risk | superseded |
| D2 | **Notifications and documents**: build as generic platform services (other runtimes need them) or inside ER first | generic ports, first implementation in ER | open |
| D3 | **Who approves test marks** (form master, head of department, head teacher) | head of department then head teacher; form master approves attendance only | **DECIDED (Femi; relayed to the ER session 2026-10-17, Decisions_Log line owed)**: head of department then head teacher, **configurable per school** |
| D4 | **Late-sync deadline** for offline marks and attendance | was a per-school setting | **moot** (2026-10-15: no offline sync); the mark deadline is compared with the server's receive time |
| D5 | **First country pack**: Nigeria reference, or Sierra Leone first | Nigeria is the spec's reference; Sierra Leone is the stated Mano River arrowhead: choose, because the exam and census packs differ | open |
| D6 | **Tuition VAT category and over-term revenue recognition** | Finance decides per jurisdiction; do not default | with CM (batch) |
| D7 | **Boarding in the first phases?** | no, P2, unless the pilot school boards | open |
| D8 | **Clearance policy**: may a school withhold report cards for unpaid fees | no default, needs counsel and a per-country rule | open |
| D9 | **Contracting entity and processor role** for children's data | needs counsel; scoped before the first paying school | open |
| D10 | **Statutory returns**: who obtains the formats from local partners | the country lead named by Femi, ER specifies | open |
| D11 | **Positions and rankings default** (on or off) and **promotion criteria defaults** | (was: off by default) | **DECIDED (Femi; relayed to the ER session 2026-10-17, Decisions_Log line owed)**: positions stay **ON by default**, school-configurable; promotion defaults to the **overall average plus the compulsory subjects** |
| D12 | **Staff: employ once through HR**, ER keeps only the teaching record | yes | open |
| D24 | **Do ER school roles (duties) fall under the access-change approval rule** (Personnel P8: a delegate raises, only the Business Owner approves)? Today the school admin grants ER duties directly | ER's reading: P8 covers EA's invite, roles, modules and remove; ER duties follow once that request flow exists, and until then the admin keeps granting (Femi 2026-10-15: delegates keep acting directly). EA and CM to confirm the reading before it is put to Femi | open |
| D25 | **Guardian messages: email first, push later** (decided for the app's notifications 2026-10-15). Does "email first" also govern guardian messaging, where the spec assumes SMS and the SMS account is blocked? | an email adapter first in the notifications port, SMS when the account exists; many guardians may have no email, so SMS stays the target channel | open |
| D26 | **Online-only and schools with power and signal cuts**: with no offline entry, what does a school do on a day with no signal (register and marks on paper, entered later)? Is a paper fallback the accepted answer for the pilot, and is any short outbox of not-yet-sent entries allowed (CM's 2026-10-15 reading says none; Femi has not confirmed) | paper fallback for the pilot, pick a school with workable connectivity, ask Femi only if a pilot school cannot meet that | open |

D3, D4, D11 and D1 are closed above. D6 is decided (Part 4 section 6).

## 11. Contributors and review

SOP, IM, POP, GL, HR and EA contribute the contracts they enforce (Part 2); WEB contributes the UX for each area (Part 3); CM reviews deploy, security and operations. Each part lands as its own docs-only branch for CM to review before the next begins.

## 12. Next: Part 2 (Plan / SRS)

Numbered requirements per area in section 3, each tagged with its spec id, owner (ER or generic), phase and role; the RBAC matrix; offline and low-bandwidth requirements per entity; children's-data and retention requirements; the integration contracts per generic service; non-functional requirements; acceptance criteria. It will **select and correct** the spec's 230 requirements; it will not rewrite them.
