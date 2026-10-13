# Education Runtime Playbook, part 2 of 4: Plan / Software Requirements (P)

**Status:** DRAFT, 2026-10-13, planning only; nothing is built before Femi approves the whole Playbook (parts 1 to 4 together). Part 1 (Scope) is `docs/ER_Playbook_1_Scope.md` (merged). Written by the Education Runtime (+ER) session. Evidence tags as in part 1: **[code]** read in `fish-education-runtime` on 2026-10-13, **[spec]** technical specification v0.1, **[decided]** recorded Femi decision, **[TBC]** unverified or undecided.

**How this part relates to the specification.** The v0.1 spec (230 requirements) stays the requirements source. This part does not copy it. It (1) **selects** what the Playbook commits to, per area, with the spec id; (2) **corrects** the spec where the code, a decision or the platform contradicts it (section 2); (3) adds the **requirements the spec does not have** because the platform changed (no duplication, tuition through SOP, runtime rules); (4) **marks the gates**: what CM must review before any build.

## 0. How to read the tables

| Column | Meaning |
|---|---|
| **ID** | `PL-<area>-<n>`: this Playbook's requirement |
| **Spec** | the v0.1 id it comes from (blank if new) |
| **Owner** | **ER** = the Education Runtime builds it; **G:name** = a generic service supplies it and ER only consumes it |
| **Ph** | phase from part 1 section 9 (P1 pilot floor, P2, P3); **done** = built |
| **Gate** | **⚑** = CM review before any build (an RBAC change, a new service-account scope, a cross-Tenant read, or a children's-data export, per CM's request); blank = ordinary review |
| **State** | **[code]** today: built, partial or none |

Priority is the spec's (Must, Should, Could) unless the row says otherwise. Roles use the real names: SCHOOL_ADMIN, HEAD_TEACHER, HOD, HOY, TEACHER (the form master is a teacher, see PL-CLS-3), REGISTRAR, ADMISSIONS_OFFICER, TIMETABLER, FEE_OFFICER, BURSAR, SAFEGUARDING_LEAD, PASTORAL_LEAD, GUARDIAN (alias PARENT), and the device account.

## 1. Gate summary: what CM must review before any build

| Gate type | Requirements |
|---|---|
| **RBAC changes** (roles, predicates, grants) | PL-ADM-5, PL-CLS-3, PL-ASM-4, PL-ASM-9, PL-SAF-1, PL-SAF-5, PL-STF-4, PL-SET-3, PL-SET-5, PL-CON-6, PL-FEE-10, PL-BRD-1, PL-STF-9 |
| **New service-account scopes** (a new route a runtime may call at a generic service) | PL-FEE-2, PL-FEE-3, PL-FEE-7, PL-FEE-9, PL-FEE-11, PL-FEE-12, PL-NOT-1, PL-DOC-2, PL-STF-5 (inbound route from EA) |
| **Cross-Tenant or cross-Company reads** | PL-RPT-6 (group dashboards), PL-SET-6 (multi-school groups); every generic-service read is already per Company |
| **Children's-data exports** | PL-ENR-9, PL-EXM-2, PL-RPT-4, PL-RPT-5, PL-IMP-3, PL-PRV-5 |
| **Authentication changes** | PL-PRT-1 (guardian OTP login), PL-SET-4 (MFA for school staff) |

### 1.1 Deferred enforcement (Femi, 2026-10-13: "RBAC is still essential but perhaps easier turned on when other features are built")

**Working rule.** Design every new permission now (name, default holders, who may do what), **build the feature first**, and **enforce the new permission afterwards behind a flag that defaults OFF** (the same pattern as the owner-MFA flags). Each flag below is on CM's **Live-switch checklist** so none is forgotten. **Nothing here weakens any check that exists today** (no loosening), and the **RBAC freeze stays** for anything that changes who can do what today; a flag turned ON is a CM-reviewed change, not a code deploy. A division label is never an authorisation. While a flag is OFF the feature works as it does today (nobody newly refused), and the new permission is recorded and shown but not enforced.

| # | New permission or rule | Requirement | Flag (default OFF) | Where | Default holders (to confirm) | Condition to switch ON |
|---|---|---|---|---|---|---|
| E1 | **Set pay basis**, **run payroll**, **approve a pay run** (three separate; preparer is not the approver) | PL-STF-9 | `HR_ENFORCE_PAY_SPLIT` | HR, EA | Proprietor and HR officer set basis; accountant or bursar run; a different person approves | Pay basis on the employment record built; HR's run and approve are separate steps; the Payroll screen is split by division; UAT passed |
| E2 | **Admin alone loses safeguarding access**; break-glass with reason, time limit and alert | PL-SAF-1 | `ER_ENFORCE_SAFEGUARDING_ADMIN_DENY` | ER | safeguarding lead, pastoral lead, head teacher | **D13** decided (if Femi chooses "now" it ships as an add-a-deny instead and this flag is dropped); the safeguarding lead role is assigned in each school |
| E3 | **Admin loses the student writes** (create, CSV, photo, transfer, identity link) | PL-ADM-5, D14 | `ER_ENFORCE_ADMIN_STUDENT_WRITE_DENY` | ER | registrar (and an admin who also holds REGISTRAR) | the Roles-and-access screen is live and every school has a registrar; at the dev-to-Live switch |
| E4 | **Form-master approval of the register** (arm-scoped teacher, delegable) | PL-CLS-3, PL-ATT-8 | `ER_ENFORCE_FORM_MASTER_APPROVAL` | ER | the form master of the arm | the arm-scoped assignment exists and each arm has one; **D3**-style default confirmed |
| E5 | **Result approval chain and locking** (published marks locked; changes need approval) | PL-ASM-4 | `ER_ENFORCE_RESULT_APPROVAL` | ER | per **D3** (head of department then head teacher, proposed) | approvers assigned per school; **D3** decided; report-card publication built |
| E6 | **Promotion approval** by the head teacher | PL-ASM-9 | `ER_ENFORCE_PROMOTION_APPROVAL` | ER | head teacher | promotion run built; **D11** defaults decided |
| E7 | **Contact restrictions block release and pickup** (court orders) | PL-CON-6 | `ER_ENFORCE_CONTACT_RESTRICTIONS` | ER | safeguarding lead, head teacher see detail | the contacts model is live; restricted flags captured for existing students |
| E8 | **Vetting data visible only** to the head teacher, safeguarding lead, admin | PL-STF-4 | `ER_ENFORCE_VETTING_VISIBILITY` | ER | as stated | the teaching record is live |
| E9 | **Document sensitivity levels** (a document inherits its record's permission plus a type level) | PL-DOC-2 | `ER_ENFORCE_DOCUMENT_SENSITIVITY` | ER | by document type | documents port built (**D2**) |
| E10 | **Segregation of duties in fees** (who records a payment cannot approve a waiver or void a receipt) | PL-FEE-10 | `ER_ENFORCE_FEE_SEGREGATION` | ER | bursar approves, fee officer records | waivers and receipts built; **D8** decided |
| E11 | **Export of restricted fields** needs the field permission and is logged | PL-RPT-4 | `ER_ENFORCE_EXPORT_FIELD_RESTRICTIONS` | ER | by field | the logging is built (it is not behind a flag); standard reports built |
| E12 | **Service-account scope** for sales, collections and reads at SOP, and the school rule | PL-FEE-2, 3, 7 | existing audience switch (unset audience refuses every ER token) | SOP, EA | the Education Runtime service account | the **data fix** (real school Companies correct in EA), the EA route live, and CM says so; already a deliberate switch |
| E13 | **Guardian sign-in** (phone and one-time code) and **MFA for school staff** | PL-PRT-1, PL-SET-4 | the owner-MFA flags (existing pattern) | CM, EA, ER | n/a | the Live switch (decided); SMS or Cognito phone path available |

**Rules for the list.** A flag's name and its switch-on condition are written into the task that builds the feature; the task's definition of done includes "listed in this table"; CM's Live-switch checklist is regenerated from this table so it cannot drift; removing a flag (enforcement permanent) is a CM-reviewed change. Anything that **tightens** a check without a flag (an add-a-deny) is allowed inside the freeze only with CM's review, as today. Where a requirement above lists a gate, it is reviewed by CM **before the feature is built**, and again **before its flag is turned on**.

## 2. Corrections to the specification (each needs the owner's agreement, noted)

| # | Spec says | Reality or decision | Resolution proposed here |
|---|---|---|---|
| C1 | **FIN-INT** is a two-way event bus (StudentEnrolled, BillingRunRequested, PaymentReceived and others) with a FiSH core that owns the billing account | Femi: ER does not duplicate SOP; SOP creates income. SOP is the FiSH core for tuition (MVP definition, design note Part 3). SOP has direct sale and collection routes, not that event set | ER calls SOP's credit-sale and collection routes directly, one idempotency key per invoice and per payment; the event bus is **not** built; the outbox relay carries non-financial events only. FIN-INT-001 to 009 and 011 are re-expressed as PL-FEE-1 to PL-FEE-9 |
| C2 | NFR-RBAC-004: "Administrators do not automatically get child protection access" | **[code]** `canAccessSafeguarding` includes SCHOOL_ADMIN | proposed deny: the admin loses safeguarding by default and gets it only with SAFEGUARDING_LEAD or PASTORAL_LEAD, or a logged break-glass (NFR-RBAC-005); this is **PL-SAF-1** ⚑ and a decision for Femi |
| C3 | ER-ATT-001: the form master takes the register per arm | **[code]** no form master is modelled; attendance is gated by role only | model the form master as a teacher assigned to an arm (PL-CLS-3) ⚑; **[decided]** attendance approval is the form master's, delegable |
| C4 | ER-ASM-004: teacher, form master, principal approve results | **[decided]** the form master is **not** the default approver of test marks; the approver is open (D3 with CM) | the approval chain is configurable per school; default settles with D3 (PL-ASM-4) ⚑ |
| C5 | ER-STF-001 holds contact details, next of kin, start and exit dates | **[decided]** staff are employed once through HR; HR owns employment | ER holds only the **teaching record** (subjects, arms, registration, vetting, expiry); contacts and employment come from HR by reference (PL-STF-1 to 5) |
| C6 | NFR-SEC-003: MFA mandatory for privileged and finance roles | **[decided]** Owner MFA policy parked until the Live switch; flags stay off | MFA is a Live-switch item, not a pilot-floor requirement; PL-SET-4 is phased accordingly |
| C7 | ER-CLS-008 multi-campus within one tenant | **[decided]** one school per Company (D-ER5) | a campus is a school Company in the same Tenant; groups are a Tenant-level view (PL-SET-6) ⚑ |
| C8 | ER-FEE-007 lists eight currencies per school | **[decided]** the platform onboards SLE only across the Mano River operation; NGN, GBP, EUR have their own settings | ER shows invoice currency from SOP; the onboarded set is the platform's, not ER's (PL-FEE-8) |
| C9 | ER-ENR-002 duplicates detected on name, date of birth and parent phone | **[code]** the built rule is school, applicant reference and academic year | both: keep the built rule for admission, add the spec's name/date-of-birth/phone check as a **warning** at student creation (PL-ENR-2) |
| C10 | ER-FEE-008 clearance policy withholds report cards for unpaid fees | open and legally sensitive (D8) | P2, behind the decision; PL-FEE-10 is **Could** until D8 |
| C11 | NFR-HST: in-country or regional hosting options | **[code]** one AWS region (London) for every service | residency per country is parked (Localization Principle); PL-PRV-7 records it, no build |
| C12 | NFR-SEC-003 phone + OTP login for parents | **[code]** guardians sign in through the platform identity today | the OTP login is a platform authentication change (PL-PRT-1) ⚑, not an ER feature |
| C13 | NFR-RBAC-003 scoped access (teacher sees own subjects and arms; house master sees house) | **[code]** a plain TEACHER is scoped to assigned lessons for roster and curriculum; houses do not exist | extend the same scoping rule to marks and attendance corrections; house scoping arrives with houses (P2) |

## 3. Requirements by area

### 3.1 Admissions and enrolment (ER-ENR)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-ADM-1 | The pipeline Submitted, Under review, Offered, Accepted or Declined, Enrolled, forward only, one step at a time | ENR-001 | ER | done | | built |
| PL-ADM-2 | A create control and a list for applications in WEB, using the school vocabulary | ENR-001, ENR-010 | WEB | P1 | | no create control (UAT 2026-10-12) |
| PL-ADM-3 | Offer letters generated from system data, stored as documents, reference kept | ENR-001, DOC-007 | ER + G:documents | P1 | | reference only today |
| PL-ADM-4 | Enrolment creates the student and starts the guardian billing account; **no tuition invoice is raised until a fee schedule applies** | ENR-001 | ER | P1 | | enrolment creates the student |
| PL-ADM-5 | Who may do which step: admissions officer up to Accepted; registrar or admin to Enrol; the head teacher decides offers (configurable) | ENR-001 | ER | P1 | ⚑ | partly: officer to Accepted, registrar or admin to Enrol |
| PL-ADM-6 | Entrance exam and interview scheduling and results | ENR-001, ENR-010 | ER | P2 | | none |

### 3.2 Student records (ER-ENR)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-ENR-1 | Student master: names, preferred name, date of birth, sex, class, photograph reference, guardians | ENR-001 | ER | P1 | | no date of birth or bio-data today |
| PL-ENR-2 | Admission number in a configurable format; duplicate check (built rule plus a name, date of birth and phone warning) | ENR-002 | ER | P1 | | none; duplicate rule differs (C9) |
| PL-ENR-3 | Configurable bio-data fields (nationality, state or region of origin, languages, previous school, special needs); each field switchable per school and country | ENR-003, PRV-001 | ER | P1 | | none |
| PL-ENR-4 | Sensitive identifiers (national ID, exam numbers, religion) optional and masked by default | ENR-004, PRV-007 | ER | P1 | | none |
| PL-ENR-5 | Health summary (blood group, allergies, conditions, medication, emergency consent), visible to authorised staff, restricted otherwise | ENR-005 | ER | P1 | | none |
| PL-ENR-6 | Effective-dated history of key fields, who and when | ENR-008 | ER | done | | built (audit history) |
| PL-ENR-7 | Withdrawal, transfer and graduation with reason, destination and clearance check; transfer letter or testimonial | ENR-007 | ER | P2 | | class transfers only |
| PL-ENR-8 | Student photograph with consent, device camera, compressed | ENR-009 | ER | P1 | | URL reference only |
| PL-ENR-9 | Student CSV import and export with preview, dry run, error report; export is logged | IMP-001, RPT-004 | ER | done | ⚑ (export) | built (import and export) |

### 3.3 Guardians and contacts (ER-CON)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-CON-1 | Many contacts per student, a contact may serve several students (siblings); several validated phone numbers; primary and WhatsApp flags | CON-001, 002 | ER | P1 | | one embedded list |
| PL-CON-2 | Emergency priority order; communication preferences and opt-out of non-essential messages | CON-003, 007 | ER | P1 | | none |
| PL-CON-3 | Legal guardian and custody status; the **fee payer** (who is billed) linked to the SOP guardian Customer | CON-004 | ER + G:SOP | P1 | | guardian account to Customer built |
| PL-CON-4 | Authorised pickup persons with photo and ID reference | CON-006 | ER | P2 | | none |
| PL-CON-5 | Consent records (what, when, how, who gave it) | CON-008, PRV-003 | ER | P1 | | none |
| PL-CON-6 | Court order and contact-restriction flags: prominent warning, restricted to the safeguarding lead and head teacher, blocks release of information and pickup | CON-005 | ER | P1 | ⚑ | none |

### 3.4 Staff records (ER-STF) (teaching record only, C5)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-STF-1 | A teaching record per person: subjects and arms taught, department; identity, contact and employment by reference to HR | STF-001, 002 | ER + G:HR | P1 | | roles and teacher-subject assignments only |
| PL-STF-2 | Professional registration (TRCN, NTC, TSC; country list TBC) with expiry | STF-003 | ER | P1 | | none |
| PL-STF-3 | Vetting and safeguarding checks: identity, references, background check, child-protection training; restricted view | STF-004, 005 | ER | P1 | | none |
| PL-STF-4 | Who may see vetting data: head teacher, safeguarding lead, admin (decided); not other teachers | STF-004 | ER | P1 | ⚑ | none |
| PL-STF-5 | "Employ once through HR": the Owner Admin employs in HR; HR pushes one command to EA; EA pushes to ER `PUT /schools/{schoolId}/staff/{email}/employment` (employmentId, TEACHER duty only, dates, version) and an end route on dismissal. **ER never calls HR**; it holds the teaching record and the employmentId. A new inbound service-account route (corrected 2026-10-13 after EA's reply) | STF-001 | ER + G:EA, G:HR | P1 | ⚑ | designed, not built; open: which EA Role a teacher holds |
| PL-STF-6 | Expiry reminders for registrations, checks, contracts | STF-006 | ER | P2 | | none |
| PL-STF-7 | Staff data for ministry returns | STF-007 | ER | P2 | | none |
| PL-STF-8 | **Staff division** (Femi 2026-10-13, superseding the earlier kinds): every staff member belongs to a **division**, **Operations** (teaching), **Administrative** (the Registry; the Proprietor is shown above), **Finance**, an attribute of the **HR employment** carried in the EA push to ER; shown inside the three existing tabs, **no fourth top-level tab**; a person appears in every division where they hold a role, payroll in the primary one; only Operations staff have a teaching record | (Femi) | G:HR, G:EA, ER, WEB | P1 | | not modelled: HR carries only staff, teacher, non-teaching staff |
| PL-STF-9 | **Payroll split** (Femi 2026-10-13: the basis of a pay is Administrative, the pay run is Financial, "RBAC"): the **pay basis** (time, piece, contract or salary) is a field on the HR employment record set by an Administrative permission; the **pay run** (run, approve, post) is Finance with a separate permission; setting a basis never implies running payroll, and the preparer of a run is not its approver; HR owns it, ER only displays the division | (Femi) | G:HR, G:EA, WEB | P1 | ⚑ | to be confirmed by HR: what the employment record holds today |

### 3.5 School structure, timetable and curriculum (ER-CLS)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-CLS-1 | Sessions and terms with dates; levels per country variant | CLS-001 | ER | done | | terms built; levels per country not |
| PL-CLS-2 | Arms within levels with capacity | CLS-002 | ER | done | | class sections built |
| PL-CLS-3 | The **form master** modelled as a teacher assigned to an arm (a role scoped to an arm, not a new global role) | CLS-002, ATT-001 | ER | P1 | ⚑ | not modelled |
| PL-CLS-4 | Senior streams or programmes; subject catalogue per level and stream; student subject combinations with validation | CLS-003, 004 | ER | P1 | | none |
| PL-CLS-5 | Houses and house masters; prefects | CLS-005, 006 | ER | P2 | | none |
| PL-CLS-6 | A simple timetable: lessons, rooms, teacher-subject assignment, conflicts; WEB add-lesson control | CLS-007 | ER, WEB | done | | API built; no create control in WEB |
| PL-CLS-7 | Curriculum topics, progress and scheduled lessons | (BK-CUR) | ER | done | | built; **writes are the teaching roles' (decided)** |
| PL-CLS-8 | Multi-campus: a campus is a school Company in the same Tenant (C7) | CLS-008 | ER + G:EA | P2 | | one school per Company |

### 3.6 Attendance (ER-ATT)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-ATT-1 | Daily register per arm with configurable status codes (nine-code table) | ATT-001 | ER | done | | built |
| PL-ATT-2 | Works fully offline on a registered device and syncs later with no loss | ATT-002, OFF-001 | ER | P1 | | server side built; client not |
| PL-ATT-3 | Absence reasons, lateness time, **correction with a reason**, original mark and audit kept | ATT-003, 008 | ER | P1 | | replace-on-remark exists; reasons not |
| PL-ATT-4 | Lesson-by-lesson attendance by subject teachers with a flag for present at registration but absent from a lesson | ATT-004 | ER | P2 | | lesson attendance built; flag not |
| PL-ATT-5 | Same-day notice to guardians of unexplained absence (configurable) | ATT-005 | ER + G:messaging | P1 | | none |
| PL-ATT-6 | Alerts for chronic and consecutive absence to the form master and head of year | ATT-006 | ER | P1 | | none |
| PL-ATT-7 | Attendance summaries for report cards and returns | ATT-007 | ER | P1 | | none |
| PL-ATT-8 | **Who**: teachers and the form master take it; the admin alone does not (decided); approval is the form master's, delegable | (decided) | ER | done | | enforced |
| PL-ATT-9 | Device capture by a verified device account (card or Bluetooth reader), scoped to attendance and the student lookup only | ATT-009 | ER | done | | built |

### 3.7 Assessment, report cards and promotion (ER-ASM)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-ASM-1 | Score structure per level and term: CA components, weights, exam weight, total validated to 100 | ASM-001 | ER | done | | built (S1 A1) |
| PL-ASM-2 | Grading scales per level and country with bands and remarks | ASM-002 | ER | done | | built (S1 A1) |
| PL-ASM-3 | Mark entry per subject offering and class: range validation, history never deleted, idempotent offline replay, a submission deadline | ASM-003 | ER | done | | built; deadline rule is D4 |
| PL-ASM-4 | **Approval workflow** and locking: configurable chain; published results are locked; changes after locking need approval and are audited | ASM-004 | ER | P1 | ⚑ | not built (S1 A4; approver is D3) |
| PL-ASM-5 | Totals, averages, subject and class positions, highest, lowest, average per subject; positions switchable off per school or level | ASM-005 | ER | P1 | | none |
| PL-ASM-6 | Affective and psychomotor ratings with configurable scales | ASM-006 | ER | P1 | | none |
| PL-ASM-7 | Report cards per term and a cumulative or annual one, from configurable templates; PDF; the fee line is configurable | ASM-007 | ER | P1 | | none |
| PL-ASM-8 | Broadsheets per arm and level | ASM-008 | ER | P1 | | none |
| PL-ASM-9 | Promotion, repeat and probation at session end by configurable criteria, head-teacher approval, guardian notice | ASM-009 | ER | P1 | ⚑ | none |
| PL-ASM-10 | Performance analytics by subject, arm, teacher and term; SPI and TPI (formulae blocked, O1) | ASM-011 | ER | P2 | | blocked |
| PL-ASM-11 | **Who enters**: teachers including head teacher, HOD, HOY; never the admin alone or the bursar (decided) | (decided) | ER | done | | enforced |

### 3.8 External exams (ER-EXM) and boarding (ER-BRD): phase 2, scoped here so the model leaves room

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-EXM-1 | Exam bodies, series and school centre numbers as configuration per country pack | EXM-001, 012 | ER | P2 | | none |
| PL-EXM-2 | Candidate registration lists, index numbers, the body's export format (formats TBC per series), CA export, results import, certificate tracking | EXM-002 to 007 | ER | P2 | ⚑ (children's data export) | none |
| PL-BRD-1 | Hostels, rooms, beds, allocation history; exeat; visiting days; sick bay (restricted); roll call | BRD-001 to 005 | ER | P2 | ⚑ (sick bay restriction) | none |

### 3.9 Fees and billing (ER-FEE + FIN-INT), through SOP

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-FEE-1 | ER keeps the **fee schedule** (level, stream, term, day or boarding) with a **Finance-set VAT category per item, never defaulted** | FEE-001 | ER | P1 | | schedule built; category not |
| PL-FEE-2 | **Raise tuition in SOP**: ER calls SOP's credit sale; key `ER-invoice-{id}`; "raised by" is an explicit field; the Company is checked as a school | FEE-002, FIN-INT-005 | ER + G:SOP | P1 | ⚑ | ER stub today; designed (note Part 3) |
| PL-FEE-3 | **Record a verified payment in SOP**: collection call; key `ER-payment-{id}`; a parent's tick is a claim and never calls SOP | FEE-003, FIN-INT-006 | ER + G:SOP | P1 | ⚑ | stub today; T-ER3 first |
| PL-FEE-4 | ER keeps only a thin mapping (ER invoice id, student, SOP sale id); amounts and status are read through SOP, never stored as a second copy | FIN-INT-009 | ER | P1 | | invoice tables hold amounts today |
| PL-FEE-5 | Guardian billing identity: the guardian account to a SOP Customer, created idempotently (`ER-guardian-{id}`), a retryable refusal when SOP is unavailable | FIN-INT-002 | ER + G:SOP | P1 | | built; key pending SOP |
| PL-FEE-6 | Statements, outstanding and defaulter lists read through SOP; the label says including VAT when gross | FEE-005 | ER | P1 | | built over ER tables; re-point later |
| PL-FEE-7 | Receipts: SOP numbers them; ER shows and sends the link | FEE-004 | ER + G:SOP | P1 | ⚑ | none |
| PL-FEE-8 | Currency is the invoice's, from SOP; the platform's onboarded currencies apply (C8) | FEE-007 | G:SOP | P1 | | |
| PL-FEE-9 | Scholarships, bursaries, discounts, waivers: ER owns eligibility and approval; SOP posts credit | FEE-006, 009 | ER + G:SOP | P2 | ⚑ | none |
| PL-FEE-14 | **Third-party payer**: a sponsor, employer or church may pay a guardian's invoice; the **guardian stays the customer** and the sponsor is the payer of a collection applied to the invoice, recorded as payer party and reference; the guardian statement shows who paid (Femi, 2026-10-13); depends on SOP's additive payer field | FEE-003 | ER + G:SOP | P2 | ⚑ | none; SOP field not yet defined |
| PL-FEE-10 | Clearance policy (C10), segregation of duties between recording and approving | FEE-008, 009 | ER | P2 | ⚑ | decision D8 |
| PL-FEE-11 | Offline cash receipt: provisional receipt from a pre-allocated number range, posted on sync | FIN-INT-013 | ER + G:SOP | P2 | ⚑ | none; needs a SOP number-range design |
| PL-FEE-12 | Online and mobile-money payment: a payment-provider integration the platform does not yet have (O3) | FEE-003, 010 | G:SOP | P2 | ⚑ | blocked |
| PL-FEE-13 | Who: fee desk is the bursar and fee officer; admin has a read-only view (decided) | (decided) | ER | done | | enforced |

### 3.10 Communications with guardians (ER-NOT)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-NOT-1 | SMS through a configurable gateway with delivery status and cost; a generic port (D2) | NOT-001 | G:messaging (ER first) | P1 | ⚑ | none; account blocked |
| PL-NOT-2 | Templates with merge fields and languages; bulk by level, arm, fee status | NOT-004 | ER | P1 | | none |
| PL-NOT-3 | **No sensitive data in an SMS or WhatsApp message**; results and fees by secure link or short summary | NOT-005 | ER | P1 | | none |
| PL-NOT-4 | Staff alerts with role routing; safeguarding alerts only to the safeguarding group | NOT-007 | ER | P1 | | none |
| PL-NOT-5 | WhatsApp with templates and an SMS fallback; email and push | NOT-002, 003 | G:messaging | P2 | | none |
| PL-NOT-6 | Budget controls and approval for large bulk sends | NOT-006 | ER | P2 | | none |

### 3.11 Documents (ER-DOC)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-DOC-1 | Attach, version and retention-tag documents on students, staff and contacts; type allow-list and size limit; malware scan | DOC-001 to 005 | G:documents (ER first) | P1 | | none |
| PL-DOC-2 | Document types are the school's (birth certificate, transfer letter, testimonial); permission inherits the record's, plus a sensitivity level | DOC-001, 006 | ER | P1 | ⚑ | none |
| PL-DOC-3 | Transcripts and testimonials generated with a verification code | DOC-007 | ER | P2 | | none |
| PL-DOC-4 | Camera capture with offline queueing | DOC-008 | ER | P2 | | none |

### 3.12 Safeguarding, discipline and pastoral (ER-SAF)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-SAF-1 | **Safeguarding access**: the admin alone loses it; the safeguarding and pastoral leads and head teacher keep it; break-glass is logged and time-limited (C2) | RBAC-004, 005 | ER | P1 | ⚑ | admin has it today |
| PL-SAF-2 | Restricted pastoral and discipline notes with visibility levels; a "speak to the safeguarding lead" marker for other staff | SAF-001, 002 | ER | partly done | | restricted notes, flag, masking and access log built |
| PL-SAF-3 | Incident reporting with referral steps and escalation timestamps | SAF-003 | ER | P2 | | none |
| PL-SAF-4 | Gate and visitor log, offline | SAF-004 | ER | P2 | | none |
| PL-SAF-5 | Pickup verification against authorised persons, optional one-time code by SMS; unauthorised attempts alerted | SAF-005 | ER | P2 | ⚑ | needs PL-CON-4 |
| PL-SAF-6 | Evacuation and emergency list generated offline | SAF-006 | ER | P2 | | none |
| PL-SAF-7 | Suspensions and expulsions with approvals and guardian notice; missing-student workflow | SAF-008, 009 | ER | P2 | | none |

### 3.13 Reporting, search and statutory returns (ER-RPT, ER-IMP)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-RPT-1 | Quick search by name, admission number, exam number or guardian phone | RPT-001 | ER | P1 | | none |
| PL-RPT-2 | Advanced filters | RPT-002 | ER | P2 | | none |
| PL-RPT-3 | Standard reports: class lists, broadsheets, report-card batches, attendance, fee collection and defaulters, staff lists | RPT-003 | ER | P1 | | lists only |
| PL-RPT-4 | Export to PDF, CSV, Excel; **every export is logged** and obeys the on-screen field restrictions | RPT-004, 006 | ER | P1 | ⚑ | register CSV only |
| PL-RPT-5 | Census and ministry returns for each country pack, in the published template; **each format is owned research**, not assumed | RPT-005 | ER | P2 | ⚑ | formats not in the repo |
| PL-RPT-6 | Dashboards for proprietors and head teachers per school and group-wide (group view crosses Companies) | RPT-008 | ER + G:EA | P2 | ⚑ | none |
| PL-IMP-1 | Bulk operations (promotion, arm reassignment, bulk invoicing, bulk message) with preview, log and reversal | IMP-003, 004 | ER | P1 | | none |
| PL-IMP-2 | Migration from spreadsheets with a reconciliation report | IMP-002 | ER | P1 | | CSV only |
| PL-IMP-3 | Full export of the school's data in open formats at any time and on exit | IMP-005 | ER | P2 | ⚑ | none |

### 3.14 Guardian and student portal (ER-PPT) (screens belong to WEB)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-PRT-1 | Guardian sign-in (phone and OTP) linked to all their children. **Not an EA build** (guardians are not EA Users): the user pool and SMS sending are CM's, the screen WEB's, ER maps a token to a guardian by phone claim (corrected 2026-10-13 after EA's reply) | PPT-001 | CM, WEB, ER | P1 | ⚑ | platform authentication change; general SMS is parked |
| PL-PRT-2 | View published results, attendance, timetable, notices; **per-child scope**: a guardian sees only a linked child | PPT-002, 005 | ER, WEB | P1 | | API built (per-child read decided and live); no WEB screens confirmed |
| PL-PRT-3 | Fee statements, invoices, payment through the platform's session, receipts | PPT-003, FIN-INT-007 | ER + G:SOP | P1 | | invoices read; no payment channel |
| PL-PRT-4 | Low-data mode and SMS result summaries | PPT-006 | ER, WEB | P2 | | none |
| PL-PRT-5 | Exeat requests, contact updates with approval, consent forms | PPT-004 | ER | P2 | | none |

### 3.15 School set-up, roles, devices, privacy (platform of the runtime)

| ID | Requirement | Spec | Owner | Ph | Gate | State |
|---|---|---|---|---|---|---|
| PL-SET-1 | School provisioned by EA (school id, organisation id) and a first admin set by EA, both idempotent | | G:EA, ER | done | | built |
| PL-SET-2 | School profile and settings (levels, terms, grading, positions on or off, fee line on report cards) as configuration packs per country | CLS-001 | ER | P1 | | none |
| PL-SET-3 | **A Roles-and-access screen under School Administration** (was "Staff-and-roles screen") so an admin can give roles (today API only); a brand-new school cannot grade or bill until roles are assigned | | ER, WEB | P1 | ⚑ | no screen |
| PL-SET-4 | MFA for school staff on privileged and finance roles (Live-switch item, C6) | SEC-003 | G:EA | Live | ⚑ | parked |
| PL-SET-5 | Termly access review report and prompt removal of leavers; the closed role list and the last-admin guard stay | RBAC-006 | ER | P1 | ⚑ | guard built |
| PL-SET-6 | Multi-school groups: a Tenant view across school Companies (C7); every read stays per Company. **No EA build**: `GET /api/me` already lists them; WEB lists and calls ER per school; a group head holds an assignment in each school (corrected 2026-10-13) | CLS-008 | WEB | P2 | ⚑ | none |
| PL-SET-7 | Registered devices: register, revoke, wipe offline data remotely | SEC-006 | ER | P1 | | register and revoke built; wipe not |
| PL-PRV-1 | Lawful basis recorded per data category; children under 18; guardian consent where consent is the basis | PRV-002, 003 | ER | P1 | | none |
| PL-PRV-2 | Retention schedule by record type per country (defaults TBC); disposal review list | PRV-006 | ER | P1 | | none |
| PL-PRV-3 | Data-subject requests: access, correction, erasure, restriction, portability, with a log and per-country deadlines | PRV-005 | ER | P2 | | none |
| PL-PRV-4 | DPIA support: data inventory, sub-processors, security documentation; the school completes the DPIA | PRV-004 | ER | P1 | | none |
| PL-PRV-5 | Pseudonymised exports for analytics and group reporting | PRV-010 | ER | P3 | ⚑ | none |
| PL-PRV-6 | Student data is never used for marketing, profiling or training AI models | PRV-008 | ER | P1 | | policy |
| PL-PRV-7 | Hosting and residency per country: recorded, not built (C11) | HST | CM | later | | parked |
| PL-AUD-1 | Append-only audit of logins, creates, edits, exports, score changes after locking, payment actions, permission changes and views of restricted records, kept at least six years (proposed) | AUD-001 to 004 | ER | P1 | | audit history and pastoral access log exist; the rest not |

## 4. RBAC matrix (capability model: V view, E enter, A approve, M administer; blank = none)

Decided cells are marked †; others are proposals for D3 and the freeze process.

| Area | ADMIN | HEAD | HOD / HOY | TEACHER | REGISTRAR | ADM. OFFICER | TIMETABLER | BURSAR / FEE OFFICER | SAFEGUARDING / PASTORAL | GUARDIAN |
|---|---|---|---|---|---|---|---|---|---|---|
| Admissions | V† M | A | | | E A (enrol) | E (to Accepted)† | | | | own application |
| Student records | V† E† (until a registrar exists) | V | V | V (own classes) | E M | V | | V (billing fields) | V | own child |
| Contacts and pickup | V | V | V | V | E | | | V (payer) | V E | own |
| Staff teaching record | V M | V A | V | own | | | | | V (vetting) | |
| Structure, timetable | V† | V | V | V | | | E M | | | V (timetable of child) |
| Curriculum | V† | V A | V E | E† | | | | | | |
| Attendance | V | V | E (+ approve, form master†) | E† | | | | | V | own child |
| Marks | V | A (D3) | E A (D3) | E† | | | | | | published only |
| Report cards, promotion | V | A | V | V | | | | | | own child, published |
| Fees | V† | V | | | | | | E† M† | | own invoices |
| Safeguarding | proposed none by default (C2) ⚑ | V | | marker only | | | | | V E M | none |
| Documents | by type | by type | by type | by type | by type | by type | | fee documents | restricted | own |
| Reports and exports | V | V | V | own classes | V | V | | finance reports | restricted | |
| Roles and devices | M | | | | | | | | | |

## 5. Offline and low-bandwidth requirements per entity

Which entities work offline, queue, or need a connection, and the conflict rule (spec NFR-OFF-003 sketch; the final rule per entity is a design pass in part 4):

| Entity | Offline | Conflict rule proposed |
|---|---|---|
| Attendance mark | works offline, syncs | last mark wins per student per register, original kept in history |
| Mark (score) | works offline, syncs | never silently overwritten: a version per cell; a later edit flags for review (built: cell version and history) |
| Student, class, timetable lookup | read offline | read-only cache with a last-synced time |
| Gate and visitor log, incident notes | works offline | append-only, no conflict |
| Admission capture | works offline | duplicate check on sync; flagged, not merged |
| Cash receipt | provisional offline, posted when synced | duplicate-flagged by the receipt number range (PL-FEE-11) |
| Raise invoice, record verified payment, publish report cards | **online only** | |
| Guardian contact edit | works offline | last writer wins, previous value kept |

Requirements: a visible sync queue and status; resumable uploads; the late-sync deadline rule is **D4**; device clock integrity with server time recorded at sync; no loss on a power cut; low-bandwidth mode (paged lists, small payloads, compressed images); SMS fallback for critical alerts. The offline client store is a **WEB and ER joint design** (part 4).

## 6. Children's-data requirements

| Data class | Examples | Who sees it | Retention (TBC per country) | Export |
|---|---|---|---|---|
| Identity and bio-data | name, date of birth, class | staff by role; guardian own child | academic: long-term; leavers by schedule | logged ⚑ |
| Sensitive identifiers | national ID, religion, exam numbers | masked by default | by schedule | never in bulk exports unless asked, logged ⚑ |
| Health | allergies, conditions, medication | head teacher, admin, named staff; evacuation list offline | by schedule | restricted |
| Safeguarding and pastoral | notes, flags, referrals | safeguarding group only (C2) | longest, by law | restricted, never in SMS |
| Photographs | student photo | staff by role | with the record; consent recorded | on request |
| Contacts and custody | phones, court orders | by role; restricted flags | with the record | logged |
| Financial | invoices, balances | fee desk, guardian own | financial record rules (TBC) | via SOP |

Rules: minimum collection, fields switchable per school and country; purpose and lawful basis recorded; field-level restriction at the API (built for safeguarding fields); every read of a restricted record logged (built for pastoral); no sensitive data in a message; no AI-training use.

## 7. Integration contracts (what ER calls at each generic service)

| Service | ER calls | Key | Failure mapping | Gate |
|---|---|---|---|---|
| **SOP** | customer create and read (cleared); credit sale; collection; reads of balances and sales | `ER-guardian-{id}`, `ER-invoice-{id}`, `ER-payment-{id}` | 401 or 403 means `billing_not_enabled`; 503 or unreachable means `billing_unavailable`; anything else loud | new routes ⚑ per route |
| **EA** | none; EA calls ER (provisioning, first admin) | idempotent on organisation id | | fixtures wave 2 |
| **HR** | none: HR pushes to EA and EA pushes to ER (corrected 2026-10-13); ER never calls HR | | | PL-STF-5 ⚑ |
| **GL** | none, ever | | | |
| **IM / POP** | none | | | |
| **Messaging, documents** | generic ports, ER first (D2) | per message and per file | | PL-NOT-1, PL-DOC-2 ⚑ |

Contract rules (part 2 of the design note, R-1 to R-5): EA decides which Company is a school; ER never posts to the ledger; every call is retry-safe; strict decoding of access payloads; every response ER provides or consumes has a fixture in `fish-contracts`.

## 8. Non-functional requirements selected for the Playbook

Taken from the spec and tied to what the platform decided: security (TLS, encryption at rest, device management, annual penetration test, 24-hour breach notice to the school), RBAC deny by default with field-level restriction, audit append-only, backup (RPO 24 hours and RTO 8 hours proposed, restores tested six-monthly), availability (99.5 percent in school hours proposed), performance (95 percent of online loads in 3 seconds on 3G; offline operations within 1 second; report cards for 1,000 students in 10 minutes), scalability sized in part 4 against a pilot (O5), usability and localisation (English first, French packs later), maintainability (one runtime, configuration-driven country packs), interoperability (open exports, fixtures). **Proposed targets are the spec's and are not validated.**

## 9. Acceptance criteria (tailored from spec section 10.2)

1. P1 pilot floor: every P1 requirement demonstrated in UAT using the use-case scripts (part 3), on a low-cost Android device, offline for attendance and marks.
2. A full term simulated end to end: admission, attendance, scores, approval, report card, promotion; and billing, verified payment, receipt, statement, with the SOP and GL balances agreeing.
3. Three days offline on a device, then sync with no loss and correct flagging of conflicts.
4. Contract tests pass for every ER-SOP and EA-ER call; no unexplained discrepancy over a two-week pilot between ER mappings and SOP.
5. A DPIA completed and a processing agreement signed; counsel's review of the children's-data rules for the pilot country.
6. A penetration test with no unresolved critical or high finding.
7. Migrated students, contacts and opening balances reconcile with the source.
8. Every gate in section 1 has CM's recorded review before its build.

## 10. Contributors: what each is asked to confirm

| Contributor | Asked |
|---|---|
| **SOP** | the sale and collection routes' opt-in per route; the cash-account choice; "raised by"; receipt numbering and the offline number range (PL-FEE-11); whether a payment-provider channel is planned |
| **EA** | confirmed 2026-10-13: provisioning and first admin as built; guardian OTP is not EA's; group view needs no EA build; MFA at the Live switch; the HR-to-ER push (PL-STF-5), and which EA Role a teacher holds |
| **HR** | the employ-once flow and what teaching-record fields HR will not hold |
| **GL, IM, POP** | confirm ER needs nothing from them in the first two phases |
| **WEB** | the screen list per area (part 3) and the offline client design |
| **CM** | the gate list in section 1, deployment and operations review, the residency position |

## 11. Next

Part 3 (Use cases): the scripts that prove each P1 requirement (admission to enrolment, a day's register offline, a term's marks to a report card, a term's billing to payment, guardian view, a safeguarding note), with actors, main flow, alternates and error flows. Part 4 (Tasks and Order): dependency-ordered tasks with sizes, the safety foundations first, and the single consolidated decision list for Femi.
