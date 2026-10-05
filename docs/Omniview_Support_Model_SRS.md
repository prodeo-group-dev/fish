# Omniview Support Model: Software Requirements Specification

**SPUTO, step P (Plan), with S (Scope) in section 1.** Companions:
`docs/Omniview_Support_Model_Use_Cases.md` (U), `docs/Omniview_Support_Model_Backlog.md` (T and O).
**Status:** draft for Femi's review, 2026-10-05. **Planning only: nothing here is built or decided
unless it is marked DECIDED.** Statuses used: **DECIDED** (Femi's own words, quoted), **BUILT**
(in `fish-er-omniview` today), **PROPOSED** (my recommendation, with a default), **OPEN** (needs Femi).

**Requested by Femi, 2026-10-05:** "The Omniview is for my team to provide support for all tenants.
SPUTO the support a multi-tenanted, multi organisational, cross industrial SMB would need given that
they are subscribed to our GLaaS."

This document answers one question: **what does the Prodeo team need, in Omniview and around it, to
support a small or medium business that runs its books on FiSH across several organisations, several
industries and several countries?** It extends, and does not replace, the Product Support v1 that is
being brought live (`docs/Omniview_v2_*`, `docs/Omniview_Support_Operations_Runbook.md`). v1 is the
ticket core: an Owner Admin raises a ticket, an operator is alerted, answers, closes. This is the full
support operation that grows from it.

---

## 1. Scope

### 1.1 What Omniview is for

Omniview is the **Prodeo team's workbench for supporting every tenant**. Its users are Prodeo
operators, never tenants. A tenant never reaches Omniview: tenants use FiSH (WEB), FiSH talks to
Omniview through a relay (EA), and Omniview is private-network only (DECIDED, Femi: "IT CAN NEVER BE
INTERNET FACING"). Support is "integral to the software" and the top priority (Femi, 2026-10-05).

### 1.2 Who the customer is (grounded in the code, 2026-10-05)

A tenant is a business that subscribes to FiSH's General Ledger as a Service. What that means for support:

| Fact | Where it is true today | Why support cares |
|---|---|---|
| One **Tenant**, many **Companies** (group structures: e.g. Purse is one tenant, four companies) | EA `Tenant`, GL `Company`; DDD section 8 | A question always has a Company context: which entity's books, currency, jurisdiction, industry, modules |
| **One Owner Admin per tenant**; staff hold a role **per Company** | EA `Role`: OWNER_ADMIN, ACCOUNTANT, SALES_OFFICER, PURCHASING_OFFICER, INVENTORY_MANAGER, HR_OFFICER; `docs/Per_Company_RBAC_Design.md` | "I cannot see / do X" is the most predictable ticket class, and the answer is almost always a role, module or Company grant |
| **Modules** per Company, self-managed or delegated | EA `ManagedModule`: GL, HR, SOP, POP, IM, TAX, EDUCATION_RUNTIME | Support must know which modules are on before it can help |
| **Industry** per Company, immutable | EA `IndustryType`: GENERIC, SCHOOL today; designed to grow | Each industry brings its own workflows (a school has admissions, fees, timetables) and needs its own support lane |
| **Jurisdictions**: UK, IE, NG, SL, LR, GN, CI; currency policy SLE-only across Mano River | GL `Jurisdiction`; `docs/*/` tax and currency docs | Tax rules, filing calendars, working days, time zones and languages differ by country; francophone GN and CI need French |
| **Verification states** (KYB for the business, KYC for the founding admin, a 180-day grace) | EA `VerificationStatus`, `KybGracePeriodSweep` | A large share of early tickets are about getting verified; deadlines create urgency |
| **Accounting and operational modules** run through GL, SOP, POP, IM, HR, Education Runtime | live services | Faults and "how do I" questions span services; support needs a cross-service view |
| Customers are **not accountants** by default, often mobile-first, sometimes low-bandwidth | project principle (progressive, forgiving entry); Women-SME brief | Plain language, short answers, guidance inside the app |
| **Prodeo Capital is a firm of accountants** | project positioning | Support sits next to professional accountancy; the line between the two must be explicit (SD4) |

### 1.3 Principles that already bind this design (all DECIDED earlier)

1. Omniview is **never internet-facing**; it is reached over private access only.
2. Omniview is **read-only toward every other FiSH service** and writes only its own database (NFR-OV-6).
   Anything a tenant must see is **pulled by FiSH** through the relay; Omniview never pushes.
3. **In-app chat is the support channel** (D12); email and phone are deferred, not forbidden.
4. **Only the tenant's Owner Admin raises a ticket** (Femi, 2026-10-04); EA stays the relay.
5. **Alert Prodeo staff** to a new ticket (D34); **every workflow states who is told, what happens if
   nobody acts, and how it closes** (FR-OV-S32).
6. **No support-terms gate**; the terms agreement is an onboarding matter, parked (Femi, 2026-10-05).
7. Non-identification (NFR-OV-7) binds **Market Support reports only**. Support is by nature about one
   identified tenant, so ticket handling is identifiable; it is bound by least privilege and audit instead (section 3.F).
8. Tickets and aggregated market figures are **different things with different rules**; do not blend them.

### 1.4 In scope, later, out of scope

| In scope of this model (phased in the backlog) | Later, named so it is not forgotten | Out of scope here |
|---|---|---|
| The support catalogue (section 2); case handling with severity, SLA and escalation; a tenant 360 context card; self-serve answers; notices, incidents and problems; guided onboarding and proactive signals; consent-gated diagnostic access; data requests; plan-aware entitlements; specialist lanes (tax, education); support quality metrics | Extra channels (email, phone, WhatsApp, USSD), French and other languages, a public status page, customer-facing training, in-app notifications for replies | Professional accountancy advice as a billable engagement (Prodeo Capital's practice, SD4); the billing and subscription system itself (it does not exist yet, SD3); Market Support (its own track); inter-tenant trade; treasury |

---

## 2. What this customer needs: the support catalogue

Twelve families, in the order a subscriber meets them. For each: what the need is, who normally answers,
whether the tenant can self-serve, and what Omniview or its neighbours must provide.
**Tier:** L1 = Prodeo support operator; L2 = the engineer who owns the service; L3 = a specialist
(accountant or tax specialist for the jurisdiction, security lead, the education product owner).

| # | Family | Typical needs | Usual severity | Tier | Self-serve? | What the platform must provide |
|---|---|---|---|---|---|---|
| 1 | **Getting started** | Sign-up and Company registration questions; choosing an industry type (cannot be changed later); chart of accounts for the client type; base currency and jurisdiction; enabling modules and choosing self-managed or delegated | P3 | L1 | Guided checklist | Onboarding progress per tenant visible to the operator (FR-SUP-E1); in-app checklist (WEB) |
| 2 | **Verification and compliance onboarding** | KYB and KYC pending or rejected; admin phone verification; the 180-day grace deadline; document problems | P2 near a deadline, else P3 | L1, L3 for disputes | Status page in app | Verification status and deadline on the tenant card (EA, read-only) |
| 3 | **Opening figures and migration** | Moving an established business onto FiSH: opening balances at the anchor date, stock, fixed assets, receivables and payables (itemised, never a lump) | P2 (blocks go-live) | L1 then L3 accountant | Partly (CSV design exists, bulk upload not built) | Case template for migration; link to the opening-figures design; later guided bulk upload |
| 4 | **Day-to-day how-to** | Posting a journal; sales, purchase and inventory cycles; payroll runs; returns and credit notes; reports | P3 to P4 | L1 | **Yes**, this is the main deflection target | Searchable help in the app; suggested answers while typing a ticket |
| 5 | **"Why can't I...?" access** | A 403 or a missing tab or Company: role, access level, module grant or Company grant | P3, P2 if it stops payroll or posting | L1 | **Yes**, an "access explainer" | EA read model to explain the exact missing grant (FR-SUP-C3); the Owner Admin can fix it themselves |
| 6 | **Faults and errors** | Something does not post, a screen fails, a number looks wrong, an integration call fails | P2 to P1 | L1 then L2 | No | Ticket carries Company, module, jurisdiction, time and request id; link to a problem record; log correlation by request id (exists) |
| 7 | **Period end and close** | Closing or reopening a period, bank reconciliation, trial balance or balance sheet that does not balance, locked-period corrections | P2 (deadline-driven) | L1 then L3 accountant | Partly | Period-close checklist; a calendar of tenants' closes so the team can staff for month-end |
| 8 | **Tax and statutory** | Corporate income tax, VAT or GST set-up and filing by country; rate changes; filing deadlines | P2 near a deadline | L3 tax specialist | Partly (rates documented per country) | Per-jurisdiction knowledge base and **change notices** when a rate or rule changes (FR-SUP-D3) |
| 9 | **Account, plan and billing** | Plan questions, invoices, failed payment, upgrade or downgrade, cancellation, reactivation | P3, P2 if service is suspended | L1 | Partly | A subscription system and plan data **do not exist yet**; this family is blocked on SD3 |
| 10 | **People, identity and security** | Locked-out admin; staff who left; changing who is Owner Admin (single, and transfer is not built); suspected compromise; phone or password recovery | P1 if compromise, else P2 | L1, L3 security | Partly (staff removal) | Verified identity procedure; audit of the account; escalation to the security lead |
| 11 | **Data requests and exit** | Export my data; correct it; erase it; show who changed what; closing the business and leaving | P3 | L1 then Femi | No | Verified-request workflow (D17); audit queries; documented exit and retention |
| 12 | **Service status and change** | "Is FiSH down?"; planned maintenance; release notes; new features; feedback and feature requests | P1 during an incident | L1, L2 | **Yes**, notices | Platform notices pulled by FiSH (FR-SUP-D1); incident record; feedback capture |

Industry lanes add questions to families 1, 4, 6 and 12. Today the School industry brings admissions,
guardian fee billing and timetabling (Education Runtime); each new `IndustryType` adds a lane
(FR-SUP-I1).

---

## 3. Functional requirements

IDs are `FR-SUP-*`. They sit **on top of** the Product Support requirements `FR-OV-S1..S32`, which stay in force.

### A. Case handling

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-A1 | The ticket core exists: raise, reply, read marker, unread, close, idempotent retries, per-tenant quota, alert to staff, awaiting-reply ageing | BUILT (v1) |
| FR-SUP-A2 | **Categorise** every ticket by the catalogue (section 2): family and sub-category, set by the operator (and suggested from the Owner Admin's words later) | PROPOSED |
| FR-SUP-A3 | **Severity and priority** on every ticket (P1 to P4, section 5), set at triage, changeable, with a reason | PROPOSED |
| FR-SUP-A4 | **SLA clocks**: time to first response and time to next response, running only while the tenant is waiting and within the published hours; a breach raises an alert before and at the deadline | PROPOSED |
| FR-SUP-A5 | **Assignment and ownership**: a ticket has one owner (a named operator) and can be handed over; unassigned tickets are visible and age | PROPOSED |
| FR-SUP-A6 | **Internal notes**: operator-only notes on a ticket, never returned through the relay | PROPOSED |
| FR-SUP-A7 | **Canned replies (macros)** with placeholders, versioned, by category and language | PROPOSED |
| FR-SUP-A8 | **Search and filters** across tickets: tenant, Company, family, severity, status, owner, age, jurisdiction, industry, free text | PROPOSED |
| FR-SUP-A9 | **Escalation**: L1 to L2 (a service owner) or L3 (a specialist) with a handoff note; the original ticket stays the single thread the tenant sees; escalation never lets a specialist see more than the ticket and the context card allow | PROPOSED |
| FR-SUP-A10 | **Merge and link** tickets (duplicates; one underlying problem) | PROPOSED |
| FR-SUP-A11 | **Closure** is by an operator; a reply after closure starts a **new** ticket (DECIDED, D38); optional **satisfaction rating** on closure (SD10) | DECIDED / PROPOSED |

### B. Tenant context

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-B1 | A **tenant 360 card** an operator opens from any ticket: tenant name and id, status, segment, verification states and deadline, the Owner Admin, the Companies (each with jurisdiction, base currency, industry, enabled modules, staff counts per role), plan and entitlement (once it exists), open and recent tickets, active incidents that touch this tenant, onboarding progress | PROPOSED |
| FR-SUP-B2 | The card is **assembled by read-only calls** to EA (tenancy), and later GL and the other services, using Omniview's service credentials. It stores **nothing** from them beyond what a ticket needs (the Company and context captured at creation) | PROPOSED |
| FR-SUP-B3 | A new ticket **captures its context at creation**: which Company, which module or screen the Owner Admin was in, app version, jurisdiction and industry. The relay supplies it; a contract change with EA and WEB, in lockstep | PROPOSED |
| FR-SUP-B4 | The card shows **no ledger data** (journals, balances, customers) by default (SD1). Business data is reached only through consent-gated diagnostic access (section F) | PROPOSED |

### C. Self-serve and knowledge

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-C1 | A **knowledge base** authored in Omniview (versioned, by category, jurisdiction, industry and language), **pulled** by FiSH through the relay and shown in the app's help | PROPOSED |
| FR-SUP-C2 | **Suggested answers** while the Owner Admin types a ticket, so the question is answered before it is sent; the ticket still goes if they choose | PROPOSED |
| FR-SUP-C3 | An **access explainer**: "Why can't I see this?" answers from the tenant's own grants (role, access level, module, Company) and tells the Owner Admin the exact change that would fix it. EA owns it; support uses the same explanation to answer faster | PROPOSED |
| FR-SUP-C4 | Plain language and short answers by default; every article states the country and industry it applies to | PROPOSED |
| FR-SUP-C5 | Operators can promote a good reply into an article or a macro (the knowledge base grows from real tickets) | PROPOSED |

### D. Notices, incidents and problems

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-D1 | **Platform notices**: Prodeo authors a notice in Omniview (maintenance, incident, release, rate change) targeted by **module, jurisdiction, industry, plan or an explicit set of tenants**; FiSH **pulls** them through the relay and shows them in the app. Omniview never writes into a tenant's data | PROPOSED |
| FR-SUP-D2 | **Incident records**: declare, set severity, link affected services and tickets, post updates, resolve, and send a closing notice. A resolved incident prompts a short post-incident note | PROPOSED |
| FR-SUP-D3 | **Change notices** for statutory change (a rate, a threshold, a filing rule) targeted by jurisdiction, authored by the tax specialist, with the effective date | PROPOSED |
| FR-SUP-D4 | **Problem records**: many tickets, one root cause, one owner in the service's backlog. When the fix ships, every linked ticket's owner is prompted to tell the tenant (the loop closes) | PROPOSED |
| FR-SUP-D5 | A **public status page** is a separate, deliberately tiny, public thing (Omniview itself stays private); what it shows is Femi's call (SD8) | OPEN |

### E. Onboarding and proactive support

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-E1 | **Onboarding progress** per tenant, derived read-only from EA and GL (Company registered, verification state, chart of accounts set, first posting, staff invited, period opened) and shown on the card | PROPOSED |
| FR-SUP-E2 | **Health signals** an operator can see per tenant and as a worklist: onboarding stuck for N days, verification deadline near, no posting for N days after go-live, a period left open past its normal close, repeated failed postings or 4xx/5xx for the tenant | PROPOSED |
| FR-SUP-E3 | **Outreach**: a signal can prompt an operator to contact the Owner Admin. It travels as a **notice or an operator-initiated thread** that FiSH pulls, never as an email Omniview sends. Whether an operator may open a thread (D21 said no for v2) and which signals are lawful to act on are SD9 | OPEN |
| FR-SUP-E4 | Month-end **load forecast**: the team sees which tenants close this week so staffing and the P2 queue are predictable | PROPOSED |

### F. Access to tenant data (the multi-tenant safety rule)

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-F1 | **No standing operator access to any tenant's business data.** An operator sees the card (section B) and the ticket; nothing else | PROPOSED, SD1 |
| FR-SUP-F2 | **Diagnostic access by the Owner Admin's grant**: an Owner Admin grants, per ticket, a **time-boxed (for example 60 minutes), read-only, named-operator, named-Company** diagnostic view; the grant is a record, revocable at once, expires on its own, and every read through it is logged (who, when, what) | PROPOSED, SD1 |
| FR-SUP-F3 | **No impersonation, ever**: no "log in as", no acting as a user, no write path into a tenancy (NFR-OV-6). If a fix needs a change in the tenant's data, the operator tells the Owner Admin what to do, or the owning service's own change path is used with the Owner Admin present | DECIDED in principle |
| FR-SUP-F4 | An **operator access log**: every card opened, ticket read, export run and diagnostic read, by named operator, append-only, reviewable by Femi; opening a card is itself a logged read (accountability for a platform that holds many businesses' books) | PROPOSED |
| FR-SUP-F5 | **Diagnostic endpoints** per service are minimal, read-only, tenant-and-Company-scoped, and return **shape and status, not figures** by default (for example "the last 5 failed postings and why", not balances) | PROPOSED |

### G. Data requests and privacy

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-G1 | **Verified data-request workflow**: export, correction and erasure of ticket content on a request from the Owner Admin, identity verified out of band, approved by Femi, executed from the runbook, recorded (D17, `docs/Omniview_Support_Operations_Runbook.md`) | PROPOSED (manual in v1) |
| FR-SUP-G2 | **Exit**: when a tenant leaves, support runs a documented exit (final export, retention period, deletion date, confirmation) coordinated across the services that hold the tenant's data | OPEN (needs the subscription lifecycle) |
| FR-SUP-G3 | **Retention** of tickets follows a stated schedule per data class and jurisdiction, with automatic enforcement once decided | OPEN (D17) |
| FR-SUP-G4 | **Residency**: ticket text is personal data held in one UK-region database today; Irish and Nigerian customers raise residency questions that `docs/FiSH_Localization_Principle.md` already flags. Support must be able to say where a tenant's ticket data lives | OPEN |

### H. Subscription and entitlement

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-H1 | Support entitlement (hours, response targets, channels, onboarding help, a named contact) is **derived from the tenant's plan**; until a plan exists, one default entitlement applies | PROPOSED, SD3 |
| FR-SUP-H2 | The card shows subscription state (trial, active, past due, suspended, cancelling) once a subscription system exists; billing tickets link to it | BLOCKED on a subscription system |
| FR-SUP-H3 | A suspended or past-due tenant can still **raise** a support ticket about the suspension itself, and about exporting its own data | PROPOSED |

### I. Specialist lanes and routing

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-I1 | **Routing rules** send a ticket to a lane by family, industry, jurisdiction, module and severity; each lane has an owner and a backup. Lanes at the start: general, access, onboarding and verification, accounting and close, tax by jurisdiction, security, and one per industry (School first) | PROPOSED |
| FR-SUP-I2 | **Industry playbooks**: for each industry, the common questions, the owning service, the escalation contact and the self-serve articles. School: admissions, guardian fee billing, timetabling, with Education Runtime's owner as L2 | PROPOSED |
| FR-SUP-I3 | **Tax specialist lane per jurisdiction** using `docs/<country>/..._Tax_And_Currency_Settings.md` as the reference; the lane flags any answer that would be a professional judgement rather than a product explanation (SD4) | PROPOSED |

### J. Quality and management

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-J1 | **Operational metrics** for the team: volume by family, severity, jurisdiction and industry; first-response and resolution times against the SLA; backlog age; reopen rate; deflection (help article views that did not become tickets); satisfaction; operator workload. These are about Prodeo's own operation and carry no tenant ledger figures | PROPOSED |
| FR-SUP-J2 | **SLA and quality alerts** reuse the alert outbox: approaching and breached SLAs, an unassigned P1, a long-aged ticket | PROPOSED |
| FR-SUP-J3 | **Review loop**: a weekly list of top families and top problems feeds the product backlog; every problem has an owner | PROPOSED |
| FR-SUP-J4 | **Feedback capture**: feature requests and complaints are recorded as their own kind of ticket and counted, never lost in the queue | PROPOSED |

### K. Channels and language

| ID | Requirement | Status |
|---|---|---|
| FR-SUP-K1 | **In-app chat** is the channel (DECIDED). Email and a phone line are deferred. Any additional channel must satisfy the same completeness rule and keep the one-thread-per-ticket model | DECIDED / OPEN (SD7) |
| FR-SUP-K2 | **Language**: English across the current markets; **French** for Guinea and Côte d'Ivoire when those markets are onboarded (both are `onboarded: false` today) | OPEN (SD6) |
| FR-SUP-K3 | **Published support hours** in a stated time zone, shown in the app, with the response-time wording (FR-OV-S30); outside hours a P1 still alerts the on-call | PROPOSED |
| FR-SUP-K4 | **Low-bandwidth friendly**: small payloads, no attachments in v1 (D5), a draft kept on failure (already built) | BUILT / DECIDED |

---

## 4. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-SUP-1 | **Least privilege and audit** (section F): a platform that holds many businesses' books must be able to show, for any tenant, exactly which operator looked at what, and when |
| NFR-SUP-2 | **Tenant isolation in support tooling**: an operator working one tenant's ticket never sees another tenant's data in that view; cross-tenant views are limited to the queue and the metrics, which hold no ledger data |
| NFR-SUP-3 | **Read-only toward services and pull-based toward tenants** (NFR-OV-6) apply to every new feature; a feature that seems to need a write into a service is redesigned as a notice, a pull, or an Owner-Admin action |
| NFR-SUP-4 | **Nothing lost, nothing duplicated**: idempotent submits, transactional alerts, durable storage (as v1); the same for notices, incidents and diagnostic grants |
| NFR-SUP-5 | **Small connection and cost footprint**: a bounded database pool and no per-request fan-out to many services; the tenant card is assembled on demand with short timeouts and degrades to what is available |
| NFR-SUP-6 | **Support must not become the weakest door**: operator authentication stays named and revocable (D13) and moves to a managed identity group when the team grows; diagnostic access is the only path to tenant data |
| NFR-SUP-7 | **Scales with a small team**: macros, knowledge base, routing and automation are first-class so one operator can handle many tenants, and tooling comes before headcount |
| NFR-SUP-8 | **Jurisdiction-aware**: dates, working days, currency display and the legal basis for handling ticket data follow the tenant's Company, not the operator's location |

---

## 5. Severity and response targets (PROPOSED, SD2)

| Severity | Meaning (examples) | First response | Update cadence | Alert |
|---|---|---|---|---|
| **P1** | Cannot post or close a period for a business; suspected compromise; the service is down for the tenant; data looks wrong or lost | within 1 hour, **inside published hours**; outside hours the on-call is alerted | every 2 hours until a workaround | immediate to on-call |
| **P2** | A module or feature is degraded; a filing or verification deadline is within 5 working days; migration blocked | within 4 working hours | daily | at 50 percent of the target and at breach |
| **P3** | How-to, access, configuration, reporting questions | within 1 working day | on each step | at breach |
| **P4** | Requests, feedback, nice-to-have | within 3 working days | on change | none |

Published hours (PROPOSED): 08:00 to 18:00 UK time, Monday to Friday, which covers the West African
markets (UTC) and Nigeria (UTC+1) in their working day. Resolution targets are **tracked, not promised**,
until the volume justifies promising them. Plan tiers (SD3) may later shorten these for higher plans.

---

## 6. Decisions for Femi (each with a recommended default)

Answer "default" to accept all. Numbered `SD` to keep them apart from the v2 `D` series.

| # | Decision | Recommended default | Why it matters |
|---|---|---|---|
| SD1 | **What may an operator see of a tenant's business data?** (A) never; (B) only when the Owner Admin grants a time-boxed, read-only, logged diagnostic view; (C) standing access | **A now, B designed and built in a later wave, never C.** Prodeo Capital will be a firm of accountants with a duty of confidentiality to clients; standing access to every tenant's books is the wrong default for a multi-tenant ledger | Sets how support can diagnose faults, and the single biggest trust question for a financial platform |
| SD2 | **Severity levels, response targets and published hours** (section 5) | Accept section 5 as the opening position | Without stated targets "nothing sits unanswered" cannot be measured or promised |
| SD3 | **Plan and entitlement model**: no plans or billing exist anywhere in the code or docs; the SaaS payer question is still open in the engine spec | Build support with **one default entitlement** now; define plans when the subscription system is scoped; do not invent tiers here | Support tiers, SLAs and billing tickets all hang off a plan that does not yet exist |
| SD4 | **The line between product support and professional accountancy advice** | Support explains the product and how to do something in it; anything that is a judgement about the tenant's accounts or tax is a **separate engagement** by Prodeo Capital's accountants (written, billable, with its own duty of care), and support says so. Take legal advice before offering it as part of the subscription (an FSMA financial-promotion point is already flagged) | Avoids professional liability by accident; protects the accountants' independence and the product team's focus |
| SD5 | **Who may raise a ticket**: today only the Owner Admin (DECIDED). A multi-organisation SMB often has an external accountant or an HR officer who needs help | Keep Owner Admin only for v1. Revisit with a **delegated support contact per Company** named by the Owner Admin if the "ask your Owner Admin" friction shows up in the data | Respects the decision; records the likely pressure point |
| SD6 | **Languages**: French for GN and CI | English now; French support and French articles are a precondition for onboarding Guinea or Côte d'Ivoire, not an afterthought | These markets are in the plan but not yet onboarded |
| SD7 | **Further channels** (email, phone, WhatsApp, USSD) | Stay in-app until the ticket core has run a full operating cycle; then add one channel at a time, WhatsApp before email for West Africa if usage shows it, each meeting the completeness rule | Femi prioritised in-app chat (D12); this orders the rest |
| SD8 | **Platform notices and a public status page** | Notices pulled into the app now (private); a separate tiny public status page later, hosted apart from Omniview, showing only up or down per service | "Is FiSH down?" will be the most urgent ticket during an outage |
| SD9 | **Proactive outreach**: may an operator open a thread, and on which signals | Allow operator-initiated threads only for a short list of signals tied to the tenant's own deadlines (onboarding stuck, verification deadline, period left open), logged and rate-limited; no marketing | D21 said no for v2; this reopens it narrowly. Needs a lawful-basis view per jurisdiction |
| SD10 | **Satisfaction rating on closure** | Yes, a one-tap rating and an optional comment, internal use only | Cheapest honest quality signal |
| SD11 | **Who owns the knowledge base** | Support operators author; the tax specialist owns the tax articles per country; the product owner of each service reviews articles about that service | Stale answers are worse than none |
| SD12 | **Escalation and on-call staffing** | Femi is the on-call until the team has more than one operator; the L2 for each service is its owning session or engineer; the L3 roles are named in the lanes table | Alerts need a human at the end of them (D34 left the mailbox and on-call to Femi) |
| SD13 | **Ticket retention and residency by jurisdiction** | Keep until erased on a verified request (v1, D17); set a schedule with the solicitor before the first Irish or Nigerian customer; state residency honestly in the meantime | Personal data in tickets crosses borders today |

---

## 7. Dependencies and risks

| Dependency or risk | Detail | Mitigation |
|---|---|---|
| **Subscription system does not exist** | Billing, plans and entitlement (FR-SUP-H) cannot be built; SD3 | Default entitlement now; a separate scoping of subscription and billing |
| **EA owns the tenancy facts** | The tenant card, onboarding progress and access explainer need EA read routes that do not exist for support | One contract with EA (read-only, operator-service credential), sized in the backlog |
| **Other services need support diagnostics** | Diagnostic reads (F5) need a small read-only endpoint in each service | Defined once as a template; built only when SD1 B is approved |
| **Single Owner Admin** | Owner transfer is not built; a departed or locked-out owner is a hard support case | Document the identity-verification procedure now; schedule the transfer feature as a product gap |
| **Operator authentication is a shared-token bridge** | Named tokens are fine for a handful of people, not for a growing team | Move to a managed identity group before the team grows (NFR-SUP-6) |
| **Small team** | Femi is the on-call; a P1 outside hours has no second person | SD12; tooling-first (NFR-SUP-7); do not promise 24x7 |
| **Professional boundary** | The easiest way to give a tenant a wrong tax answer is to treat support as advice | SD4; the tax lane flags judgements |
| **Consent fatigue and legal drift** | Several consent-like records are now parked or proposed (support terms parked, market consent, diagnostic grant) | Keep each purpose separate (decided in D35); the diagnostic grant is per ticket and temporary |
| **Residency** | UK-region data for Irish and Nigerian customers | SD13 and the localization principle |

---

## 8. How this relates to what exists

| Already decided or built | How this model uses it |
|---|---|
| Product Support v1 (`docs/Omniview_v2_*`, `fish-er-omniview`) | It is wave S0 here; nothing in v1 is redone |
| Market Support (aggregate reports, non-identification) | A separate track. It reads GL; support reads EA and tickets. They share the private network and the operator login, nothing else |
| EA relay and Business Owner dashboard | The relay is the only door for tenant-facing support features; the dashboard may later host the notices and help |
| Education Runtime (The Principal's EduSys) | The first industry lane (FR-SUP-I2) |
| `docs/Opening_Figures_CSV_Upload_*` | Family 3's case template and later guided upload |
| `docs/Industry_Type_Module_Enablement_Design.md` | Industry as a routing dimension |
| `docs/FiSH_Localization_Principle.md` | Jurisdiction, language and residency dimensions |
